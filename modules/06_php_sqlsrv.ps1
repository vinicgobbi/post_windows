# Composer não tem pacote no winget. Segue o método "command-line
# installation" documentado em getcomposer.org/download.html (o mesmo usado
# em CI/imagens Docker): baixa o composer-setup.php, confere o hash SHA-384
# publicado pelo próprio projeto antes de rodar (não dá pra confiar cegamente
# num script baixado) e o instalador gera o composer.phar. Como .phar não é
# executável direto no Windows, cria um shim composer.bat ao lado.
function Install-Composer {
    if (Test-CommandExists "composer") {
        Write-Sucesso "Composer já está instalado."
        return
    }
    if (-not (Test-CommandExists "php")) {
        Write-Aviso "php.exe não encontrado no PATH; pulando instalação do Composer."
        return
    }

    Write-Info "Instalando Composer..."
    $composerDir = "$env:ProgramData\Composer"
    New-Item -ItemType Directory -Force -Path $composerDir | Out-Null

    $setupPath = Join-Path $env:TEMP "composer-setup.php"
    Invoke-DownloadComRetry -Url "https://getcomposer.org/installer" -Destino $setupPath

    $assinaturaEsperada = (Invoke-RestMethod -Uri "https://composer.github.io/installer.sig").Trim()
    $assinaturaReal = (Get-FileHash -Path $setupPath -Algorithm SHA384).Hash.ToLower()
    if ($assinaturaReal -ne $assinaturaEsperada) {
        Write-Aviso "Assinatura do instalador do Composer não confere; abortando por segurança."
        Remove-Item $setupPath -Force -ErrorAction SilentlyContinue
        return
    }

    & php.exe $setupPath "--install-dir=$composerDir" "--quiet" | Out-Null
    Remove-Item $setupPath -Force -ErrorAction SilentlyContinue

    $pharPath = Join-Path $composerDir "composer.phar"
    if (-not (Test-Path $pharPath)) {
        Write-Aviso "composer.phar não foi gerado; instalação do Composer falhou."
        return
    }

    $batPath = Join-Path $composerDir "composer.bat"
    Set-Content -Path $batPath -Value "@php `"%~dp0composer.phar`" %*" -Encoding ASCII

    $pathMaquina = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($pathMaquina -notmatch [regex]::Escape($composerDir)) {
        [System.Environment]::SetEnvironmentVariable("Path", "$pathMaquina;$composerDir", "Machine")
    }
    Update-SessionPath
    Write-Sucesso "Composer instalado em $composerDir."
}

function Install-PhpSqlsrv {
    Write-Info "Instalando PHP, Composer, driver ODBC 18 e as extensões sqlsrv/pdo_sqlsrv..."

    Install-WingetApp -Id "PHP.PHP.8.4" -Nome "PHP 8.4 (thread-safe)" | Out-Null
    Update-SessionPath
    Install-Composer
    Install-WingetApp -Id "Microsoft.msodbcsql.18" -Nome "Microsoft ODBC Driver 18 for SQL Server" | Out-Null
    Update-SessionPath

    $phpCmd = Get-Command php.exe -ErrorAction SilentlyContinue
    if (-not $phpCmd) {
        Write-Aviso "php.exe não encontrado no PATH após a instalação; pulando as extensões sqlsrv."
        return
    }

    # O winget instala o PHP como pacote "portable" e cria um link em
    # %LOCALAPPDATA%\Microsoft\WinGet\Links\php.exe; resolvemos o alvo real
    # do link para achar a pasta de instalação de fato (onde ficam ext/ e o php.ini).
    $phpExeReal = $phpCmd.Source
    $item = Get-Item $phpCmd.Source -ErrorAction SilentlyContinue
    if ($item -and $item.Target) { $phpExeReal = $item.Target | Select-Object -First 1 }
    $phpDir = Split-Path $phpExeReal -Parent
    $extDir = Join-Path $phpDir "ext"
    $phpIni = Join-Path $phpDir "php.ini"

    if (-not (Test-Path $phpIni)) {
        $phpIniProd = Join-Path $phpDir "php.ini-production"
        if (Test-Path $phpIniProd) {
            Copy-Item $phpIniProd $phpIni
        } else {
            Write-Aviso "php.ini não encontrado em $phpDir; pulando as extensões sqlsrv."
            return
        }
    }

    # Baixa a release mais recente do driver oficial da Microsoft (DLLs
    # pré-compiladas - no Windows não dá pra usar PECL/compilar como no Linux).
    Write-Info "Baixando o driver PHP para SQL Server (msphpsql) mais recente..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/msphpsql/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match '^Windows_.*\.zip$' } | Select-Object -First 1
    if (-not $asset) {
        Write-Aviso "Não encontrei o pacote Windows na release do msphpsql; pulando as extensões sqlsrv."
        return
    }

    $zipPath = Join-Path $env:TEMP "msphpsql.zip"
    $extractPath = Join-Path $env:TEMP "msphpsql_extract"
    Invoke-DownloadComRetry -Url $asset.browser_download_url -Destino $zipPath
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    $sqlsrvDll = "php_sqlsrv_84_ts_x64.dll"
    $pdoSqlsrvDll = "php_pdo_sqlsrv_84_ts_x64.dll"
    $origemSqlsrv = Get-ChildItem -Path $extractPath -Filter $sqlsrvDll -Recurse | Select-Object -First 1
    $origemPdo = Get-ChildItem -Path $extractPath -Filter $pdoSqlsrvDll -Recurse | Select-Object -First 1

    if (-not $origemSqlsrv -or -not $origemPdo) {
        Write-Aviso "DLLs '$sqlsrvDll'/'$pdoSqlsrvDll' não encontradas na release baixada (a nomenclatura pode ter mudado); pulando."
        return
    }

    Copy-Item $origemSqlsrv.FullName (Join-Path $extDir $sqlsrvDll) -Force
    Copy-Item $origemPdo.FullName (Join-Path $extDir $pdoSqlsrvDll) -Force

    $iniConteudo = Get-Content -Path $phpIni -Raw
    if ($iniConteudo -notmatch [regex]::Escape($sqlsrvDll)) {
        Add-Content -Path $phpIni -Value "extension=$sqlsrvDll"
    }
    if ($iniConteudo -notmatch [regex]::Escape($pdoSqlsrvDll)) {
        Add-Content -Path $phpIni -Value "extension=$pdoSqlsrvDll"
    }
    if ($iniConteudo -notmatch '(?m)^\s*extension_dir\s*=') {
        Add-Content -Path $phpIni -Value "extension_dir = `"ext`""
    }

    Remove-Item $zipPath, $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Sucesso "PHP + sqlsrv/pdo_sqlsrv configurados em $phpDir."
}

Register-Modulo -Id "php_sqlsrv" -Titulo "Instalar PHP + extensões SQL Server" `
    -Descricao "PHP 8.4, Composer, driver ODBC 18 e as extensões sqlsrv/pdo_sqlsrv (DLLs oficiais da Microsoft)" `
    -Funcao ${function:Install-PhpSqlsrv}
