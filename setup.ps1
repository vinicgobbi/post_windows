#Requires -Version 5.1
<#
    Ponto de entrada do post-install do Windows.
    Uso:  powershell -ExecutionPolicy Bypass -File .\setup.ps1
    (o script se reabre sozinho como Administrador se não estiver elevado)
#>

$script:ScriptDir = $PSScriptRoot

# Console padrão do Windows PowerShell nem sempre usa UTF-8 na saída, o que
# bugava os acentos (ã, ç, ó...) mesmo com os arquivos .ps1 em UTF-8.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { chcp 65001 | Out-Null } catch {}

# --- Carrega bibliotecas, configuração e módulos ---
. (Join-Path $script:ScriptDir "lib\UI.ps1")
. (Join-Path $script:ScriptDir "lib\SystemDetect.ps1")
. (Join-Path $script:ScriptDir "lib\Utils.ps1")
. (Join-Path $script:ScriptDir "config.ps1")
Get-ChildItem -Path (Join-Path $script:ScriptDir "modules") -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

Show-Banner

# --- Elevação: precisa ser Administrador (equivalente ao "sudo" do Linux) ---
if (-not (Test-IsAdministrator)) {
    Write-Host "[!] Este script precisa rodar como Administrador. Reabrindo elevado..." -ForegroundColor Yellow
    $exePath = (Get-Process -Id $PID).Path
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    # UseShellExecute precisa ser explicitamente $true para o Verb "runas"
    # ter efeito. No .NET Framework (Windows PowerShell 5.1) o padrão já é
    # $true, mas no .NET moderno (PowerShell 7/pwsh) o padrão é $false - sem
    # isso aqui o "runas" é ignorado em silêncio (sem UAC, sem erro) e o
    # processo reabre sem elevar, causando um loop infinito de reaberturas.
    $psi.UseShellExecute = $true
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Host "[-] Elevação cancelada pelo usuário." -ForegroundColor Red
    }
    exit
}

if (-not (Test-WingetDisponivel)) {
    Write-Host "[-] winget não encontrado. Atualize o 'App Installer' pela Microsoft Store e rode o script novamente." -ForegroundColor Red
    exit 1
}

Start-Log -Prefixo "setup"

try {
    # --- Identificação do sistema ---
    Get-InformacoesSistema
    Show-MensagemSistemaDetectado

    # No Windows a elevação (UAC) não troca o usuário logado, então o alvo da
    # configuração já é sempre quem está rodando o script - sem precisar
    # perguntar "para qual usuário", diferente do sudo no Linux.
    Write-Info "Configuração será aplicada para: $env:USERNAME"

    # --- Seleção de módulos ---
    $itensMenu = $script:ModulosRegistrados | ForEach-Object {
        [PSCustomObject]@{ Id = $_.Id; Titulo = $_.Titulo; Descricao = $_.Descricao }
    }
    $selecionadosMenu = Show-ChecklistMenu -Titulo "Escolha o que deseja executar (tudo já vem marcado):" -Itens $itensMenu

    if ($selecionadosMenu.Count -eq 0) {
        Write-Aviso "Nenhum módulo selecionado. Nada a fazer."
        exit 0
    }

    # Resolve dependências entre módulos (ex.: um módulo que precise de outro
    # já ter rodado antes) mesmo que o usuário tenha desmarcado a dependência.
    $selecionadosFinal = Resolve-DependenciasModulos -Selecionados $selecionadosMenu
    $script:SelecionadosIds = $selecionadosFinal

    # Mantém a ordem de registro dos módulos (= ordem numérica dos arquivos),
    # não a ordem em que apareceram no menu.
    $modulosParaRodar = $script:ModulosRegistrados | Where-Object { $selecionadosFinal -contains $_.Id }

    Write-Host ""
    Write-Info "Módulos selecionados:"
    foreach ($m in $modulosParaRodar) { Write-Host "  - $($m.Titulo)" }
    Write-Host ""

    if (-not (Confirm-Acao "Iniciar a configuração com os $($modulosParaRodar.Count) módulos acima?")) {
        Write-Aviso "Operação cancelada pelo usuário."
        exit 0
    }

    # --- Execução ---
    Start-RawLog
    $executados = @()
    $total = $modulosParaRodar.Count
    for ($i = 0; $i -lt $total; $i++) {
        $m = $modulosParaRodar[$i]
        Write-Passo -Atual ($i + 1) -Total $total -Titulo $m.Titulo
        try {
            & $m.Funcao
            $executados += $m.Titulo
        } catch {
            Write-Aviso "Módulo '$($m.Titulo)' falhou: $($_.Exception.Message)"
        }
    }

    Show-ResumoFinal -Executados $executados
} catch [System.Management.Automation.PipelineStoppedException] {
    # Lançada quando o usuário aperta Ctrl+C enquanto o pipeline está rodando
    # (equivalente ao "trap ... INT" do lado Linux). Sai com o mesmo código
    # de saída (130) que o bash usa para SIGINT.
    Write-Host ""
    Write-Host "[-] Cancelado pelo usuário." -ForegroundColor Red
    Write-LogLine -Nivel "ERRO" -Mensagem "Cancelado pelo usuário (Ctrl+C)."
    exit 130
} catch {
    # Qualquer erro terminante que escape do try/catch por módulo do loop
    # acima (ex.: durante o menu, a resolução de dependências ou o resumo
    # final) - equivalente ao "trap ... ERR" do lado Linux, mostrando o
    # número da linha em vez de deixar a stack trace padrão do PowerShell.
    Write-Aviso "Falha inesperada (linha $($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line.Trim())"
    exit 1
} finally {
    Stop-RawLog
}
