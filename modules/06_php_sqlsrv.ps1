function Install-PhpSqlsrv {
    Write-Info "Instalando PHP, driver ODBC 18 e as extensões sqlsrv/pdo_sqlsrv..."

    Install-WingetApp -Id "PHP.PHP.8.4" -Nome "PHP 8.4 (thread-safe)" | Out-Null
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
    -Descricao "PHP 8.4, driver ODBC 18 e as extensões sqlsrv/pdo_sqlsrv (DLLs oficiais da Microsoft)" `
    -Funcao ${function:Install-PhpSqlsrv}
