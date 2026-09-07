# ==========================================
# Utilitários gerais
# ==========================================

function Test-CommandExists {
    param([string]$Nome)
    return [bool](Get-Command -Name $Nome -ErrorAction SilentlyContinue)
}

# ------------------------------------------------------------------
# Registro de módulos: cada arquivo em modules/ chama isto no final para se
# anunciar ao orquestrador (usado para montar o menu e a ordem de execução).
# Uso: Register-Modulo -Id <id> -Titulo <titulo> -Descricao <descricao> `
#          -Funcao ${function:Nome-Da-Funcao} [-Dependencias @("outro_id")]
# ------------------------------------------------------------------
$script:ModulosRegistrados = @()

function Register-Modulo {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Titulo,
        [Parameter(Mandatory)][string]$Descricao,
        [Parameter(Mandatory)][scriptblock]$Funcao,
        [string[]]$Dependencias = @()
    )
    $script:ModulosRegistrados += [PSCustomObject]@{
        Id            = $Id
        Titulo        = $Titulo
        Descricao     = $Descricao
        Funcao        = $Funcao
        Dependencias  = $Dependencias
    }
}

# Dado o resultado do Show-ChecklistMenu (array de ids selecionados), garante
# que qualquer módulo do qual um selecionado dependa também seja incluído,
# mesmo que o usuário o tenha desmarcado - avisando qual módulo puxou qual.
# Repete em ponto fixo para cobrir cadeias de dependência (A depende de B,
# que depende de C).
function Resolve-DependenciasModulos {
    param([string[]]$Selecionados)

    $sel = [System.Collections.Generic.HashSet[string]]::new([string[]]$Selecionados)
    $porId = @{}
    foreach ($m in $script:ModulosRegistrados) { $porId[$m.Id] = $m }

    $mudou = $true
    while ($mudou) {
        $mudou = $false
        foreach ($m in $script:ModulosRegistrados) {
            if (-not $sel.Contains($m.Id)) { continue }
            foreach ($depId in $m.Dependencias) {
                if (-not $sel.Contains($depId)) {
                    $sel.Add($depId) | Out-Null
                    $mudou = $true
                    if ($porId.ContainsKey($depId)) {
                        Write-Aviso "'$($m.Titulo)' depende de '$($porId[$depId].Titulo)': selecionando automaticamente."
                    }
                }
            }
        }
    }
    return ,@($sel)
}

# Verifica se o módulo (pelo Id passado a Register-Modulo) foi escolhido
# para rodar nesta execução. Usado por módulos que mudam de comportamento
# conforme outro módulo também tenha sido selecionado.
function Test-ModuloSelecionado {
    param([string]$Id)
    return $script:SelecionadosIds -contains $Id
}

# Baixa uma URL com algumas tentativas antes de desistir, para tolerar
# instabilidade de rede em downloads diretos (instaladores sem winget/choco).
function Invoke-DownloadComRetry {
    param([string]$Url, [string]$Destino, [int]$Tentativas = 3)

    for ($i = 1; $i -le $Tentativas; $i++) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destino -UseBasicParsing
            return
        } catch {
            Write-Aviso "Falha ao baixar $Url (tentativa $i/$Tentativas): $($_.Exception.Message)"
        }
    }
    Write-ErroFatal "Não foi possível baixar $Url após $Tentativas tentativas."
}

# Acrescenta uma linha ao perfil do PowerShell só se ela ainda não estiver
# lá (idempotente em reexecuções). Cria o arquivo/pasta se não existirem.
function Add-LinhaAoPerfil {
    param([string]$Linha, [string]$PerfilPath = $PROFILE)
    $dir = Split-Path $PerfilPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path $PerfilPath)) { New-Item -ItemType File -Force -Path $PerfilPath | Out-Null }
    $conteudo = Get-Content -Path $PerfilPath -Raw -ErrorAction SilentlyContinue
    if ($conteudo -notmatch [regex]::Escape($Linha)) {
        Add-Content -Path $PerfilPath -Value $Linha
    }
}

# ------------------------------------------------------------------
# winget / Chocolatey
# ------------------------------------------------------------------

# Releituras do PATH de Machine/User: necessário depois de instalar pacotes
# portáteis (fnm, rustup) para o comando ficar disponível já nesta mesma
# sessão, sem precisar abrir um PowerShell novo.
function Update-SessionPath {
    $maquina = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $usuario = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$maquina;$usuario"
}

# Cache da lista de apps instalados via winget: evita reabrir o winget.exe
# (custa 1-3s de sincronização de fonte + ativação COM) a cada app checado.
# Montado uma única vez na primeira checagem e reaproveitado pelo resto da
# execução; atualizado incrementalmente conforme instalações vão terminando.
$script:WingetInstaladosCache = $null

function Get-WingetInstaladosCache {
    if ($null -eq $script:WingetInstaladosCache) {
        $saida = winget list --accept-source-agreements 2>$null
        $script:WingetInstaladosCache = if ($LASTEXITCODE -eq 0) { $saida -join "`n" } else { "" }
    }
    return $script:WingetInstaladosCache
}

function Test-WingetAppInstalado {
    param([string]$Id)
    return (Get-WingetInstaladosCache) -match [regex]::Escape($Id)
}

$script:ChocolateyGarantido = $false

# Instala o Chocolatey só na primeira vez que algum módulo precisar dele como
# fallback (apps que não existem no winget, ex.: FileZilla). Evita depender
# dele quando não é necessário.
function Install-Chocolatey {
    if ($script:ChocolateyGarantido -or (Test-CommandExists "choco")) {
        $script:ChocolateyGarantido = $true
        return
    }
    Write-Info "Instalando o Chocolatey (fallback para apps fora do winget)..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $script:ChocolateyGarantido = $true
    Write-Sucesso "Chocolatey instalado."
}

function Install-ChocoApp {
    param([Parameter(Mandatory)][string]$Id, [string]$Nome = $Id)
    Install-Chocolatey
    Write-Info "Instalando $Nome via Chocolatey..."
    choco install $Id -y --no-progress | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Sucesso "$Nome instalado (Chocolatey)."
        return $true
    }
    Write-Aviso "Falha ao instalar $Nome via Chocolatey (código $LASTEXITCODE)."
    return $false
}

# "winget" não é um .exe de verdade no PATH - é um App Execution Alias
# (reparse point em %LOCALAPPDATA%\Microsoft\WindowsApps que aponta pro
# pacote Microsoft.DesktopAppInstaller). Esse alias só é resolvido quando o
# processo é criado pelo mecanismo normal de ativação do shell; uma
# Scheduled Task (usada por Invoke-ComoUsuarioPadrao) não passa por isso e
# recebe ERROR_FILE_NOT_FOUND (0x80070002) ao tentar rodar "winget" pelo
# nome. Resolve o caminho real do winget.exe pra contornar isso.
function Resolve-WingetExePath {
    $pacote = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pacote) {
        $candidato = Join-Path $pacote.InstallLocation "winget.exe"
        if (Test-Path $candidato) { return $candidato }
    }
    return "winget"
}

# Roda um comando como o usuário padrão (token não elevado), mesmo com este
# script rodando como Administrador. Existe para apps cujo pacote falha ao
# instalar quando o winget roda em processo elevado (ver ScopeUsuario em
# Install-WingetApp). Usa uma tarefa agendada temporária com RunLevel
# "Limited" - é a forma suportada de "desalevear" a partir de um processo
# já elevado sem pedir credenciais de novo.
function Invoke-ComoUsuarioPadrao {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$ArgumentList = ""
    )

    $taskName = "PostWindows_Deelevate_$([guid]::NewGuid().ToString('N'))"
    try {
        $action = New-ScheduledTaskAction -Execute $FilePath -Argument $ArgumentList
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
        Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName

        do {
            Start-Sleep -Milliseconds 500
            $estado = (Get-ScheduledTask -TaskName $taskName).State
        } while ($estado -eq "Running")

        return (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
    } finally {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# Instala um app pelo Id do winget. Se não existir no winget (ChocoFallback
# informado) ou a instalação falhar, tenta o Chocolatey em seguida - o
# objetivo é sempre tentar automatizar, mesmo fora da "loja" principal.
#
# -ScopeUsuario: para apps que falham ao instalar rodando elevado (ex.:
# Spotify/WhatsApp, ver comentário em config.ps1), roda desalevado via
# Invoke-ComoUsuarioPadrao, usando o caminho real do winget.exe (ver
# Resolve-WingetExePath) já que o alias "winget" não resolve numa
# Scheduled Task.
function Install-WingetApp {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Nome = $Id,
        [string]$ChocoFallback,
        [string[]]$ArgsExtra = @(),
        [switch]$ScopeUsuario
    )

    if (Test-WingetAppInstalado -Id $Id) {
        Write-Sucesso "$Nome já está instalado."
        return $true
    }

    Write-Info "Instalando $Nome..."
    $argumentos = @('install', '--id', $Id, '-e', '--silent', '--accept-source-agreements', '--accept-package-agreements') + $ArgsExtra

    if ($ScopeUsuario) {
        $codigoSaida = Invoke-ComoUsuarioPadrao -FilePath (Resolve-WingetExePath) -ArgumentList ($argumentos -join ' ')
    } else {
        $proc = Start-Process -FilePath "winget" -ArgumentList $argumentos -Wait -PassThru -WindowStyle Hidden
        $codigoSaida = $proc.ExitCode
    }

    if ($codigoSaida -eq 0) {
        Write-Sucesso "$Nome instalado."
        Update-SessionPath
        if ($script:WingetInstaladosCache) { $script:WingetInstaladosCache += "`n$Id" }
        return $true
    }

    Write-Aviso "winget não conseguiu instalar $Nome (código $codigoSaida)."
    if ($ChocoFallback) {
        return Install-ChocoApp -Id $ChocoFallback -Nome $Nome
    }
    return $false
}
