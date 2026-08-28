# ==========================================
# Detecção de sistema (Windows)
# ==========================================
# Define, ao final de Get-InformacoesSistema, as seguintes variáveis globais:
#   WIN_EDITION   - ex.: "Windows 11 Pro"
#   WIN_BUILD     - build numérico (ex.: 26100)
#   WIN_IS_PRO    - $true se a edição suporta Hyper-V/gpedit (Pro/Enterprise/Education)
#   WIN_ARCH      - arquitetura do processador (AMD64/ARM64)

function Get-InformacoesSistema {
    $os = Get-CimInstance Win32_OperatingSystem
    $script:WIN_EDITION = $os.Caption
    $script:WIN_BUILD = [int]$os.BuildNumber
    $script:WIN_ARCH = $env:PROCESSOR_ARCHITECTURE
    $script:WIN_IS_PRO = $script:WIN_EDITION -match 'Pro|Enterprise|Education'

    if ($script:WIN_BUILD -lt 19041) {
        Write-ErroFatal "Versão do Windows não suportada (build $script:WIN_BUILD). Este script foi feito para Windows 10 2004+ ou Windows 11, onde o winget está disponível."
    }
}

function Show-MensagemSistemaDetectado {
    Write-Info "Sistema detectado: $script:WIN_EDITION (build $script:WIN_BUILD, $script:WIN_ARCH)"
}

function Test-IsAdministrator {
    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidade)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WingetDisponivel {
    return Test-CommandExists "winget"
}
