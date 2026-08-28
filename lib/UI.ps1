# ==========================================
# UI: cores, mensagens, prompts e menu interativo
# ==========================================

$script:LogFile = $null
$script:RawLogFile = $null
$script:Stopwatch = $null

function Write-Info {
    param([string]$Mensagem)
    Write-Host "[*] $Mensagem" -ForegroundColor Yellow
    Write-LogLine -Nivel "INFO" -Mensagem $Mensagem
}

function Write-Sucesso {
    param([string]$Mensagem)
    Write-Host "[+] $Mensagem" -ForegroundColor Green
    Write-LogLine -Nivel "OK" -Mensagem $Mensagem
}

function Write-Aviso {
    param([string]$Mensagem)
    Write-Host "[!] $Mensagem" -ForegroundColor Cyan
    Write-LogLine -Nivel "AVISO" -Mensagem $Mensagem
}

function Write-ErroFatal {
    param([string]$Mensagem)
    Write-Host "[-] $Mensagem" -ForegroundColor Red
    Write-LogLine -Nivel "ERRO" -Mensagem $Mensagem
    throw $Mensagem
}

function Write-Passo {
    param([int]$Atual, [int]$Total, [string]$Titulo)
    Write-Host "[$Atual/$Total] $Titulo" -ForegroundColor Blue
    Write-LogLine -Nivel "PASSO" -Mensagem "[$Atual/$Total] $Titulo"
}

# ==========================================
# Log em arquivo
# ==========================================
# Cada execução grava dois arquivos em logs/, ao lado do script:
#   <prefixo>_<timestamp>.log      - só as mensagens Info/Aviso/Erro/Sucesso/Passo
#   <prefixo>_<timestamp>.raw.log  - transcript bruto e completo (Start-Transcript),
#                                    incluindo a saída de winget/choco/dism etc.
function Start-Log {
    param([string]$Prefixo)
    $logDir = Join-Path $script:ScriptDir "logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = Join-Path $logDir "${Prefixo}_${timestamp}.log"
    $script:RawLogFile = Join-Path $logDir "${Prefixo}_${timestamp}.raw.log"
    New-Item -ItemType File -Force -Path $script:LogFile | Out-Null
    $script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Info "Log desta execução: $script:LogFile"
}

function Write-LogLine {
    param([string]$Nivel, [string]$Mensagem)
    if (-not $script:LogFile) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $script:LogFile -Value "$timestamp [$Nivel] $Mensagem"
}

# Só chamada depois do menu interativo (fase de execução dos módulos), pelo
# mesmo motivo do post_install em bash: redirecionar a saída antes quebraria
# a detecção de terminal usada pelo menu de checklist.
function Start-RawLog {
    if (-not $script:RawLogFile) { return }
    try {
        Start-Transcript -Path $script:RawLogFile -Append | Out-Null
        Write-Info "Saída completa (bruta) desta execução: $script:RawLogFile"
    } catch {
        Write-Aviso "Não foi possível iniciar o log bruto (Start-Transcript): $($_.Exception.Message)"
    }
}

function Stop-RawLog {
    try { Stop-Transcript | Out-Null } catch {}
}

function Show-Banner {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "   POST-INSTALL SETUP (Windows)" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
}

# Pergunta s/N genérica. Retorna $true (sim) ou $false (não).
function Confirm-Acao {
    param([string]$Pergunta)
    $resposta = Read-Host "[?] $Pergunta [s/N]"
    return $resposta -match '^[sSyY]$'
}

# Detecta se dá pra desenhar o menu interativo (mesma ideia do "[ -t 0 ]" do
# bash): input/output não redirecionados e rodando num console de verdade.
function Test-IsInteractiveConsole {
    try {
        return (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected) -and ($Host.Name -eq 'ConsoleHost')
    } catch {
        return $false
    }
}

# ------------------------------------------------------------------
# Menu de checklist interativo em PowerShell puro (sem módulos externos).
# $Itens: array de objetos com Id/Titulo/Descricao (ver Register-Modulo).
# Retorna o array de Ids selecionados. Se não for interativo, seleciona tudo.
# ------------------------------------------------------------------
function Show-ChecklistMenu {
    param(
        [string]$Titulo,
        [Parameter(Mandatory)][array]$Itens
    )

    $n = $Itens.Count
    $selecionado = New-Object bool[] $n
    for ($i = 0; $i -lt $n; $i++) { $selecionado[$i] = $true }

    if (-not (Test-IsInteractiveConsole)) {
        Write-Aviso "Entrada não é um console interativo: executando todos os módulos automaticamente."
        return $Itens | ForEach-Object { $_.Id }
    }

    $cursor = 0
    while ($true) {
        Clear-Host
        Write-Host $Titulo -ForegroundColor White
        Write-Host "Seta cima/baixo mover   espaço alterna   a marca/desmarca tudo   enter confirma" -ForegroundColor DarkGray
        Write-Host ""
        for ($i = 0; $i -lt $n; $i++) {
            $marca = if ($selecionado[$i]) { "x" } else { " " }
            $linha = "[$marca] $($Itens[$i].Titulo)"
            if ($i -eq $cursor) {
                Write-Host "> $linha" -ForegroundColor Green -NoNewline
                Write-Host " - $($Itens[$i].Descricao)" -ForegroundColor DarkGray
            } else {
                Write-Host "  $linha" -NoNewline
                Write-Host " - $($Itens[$i].Descricao)" -ForegroundColor DarkGray
            }
        }

        $tecla = [Console]::ReadKey($true)
        switch ($tecla.Key) {
            'UpArrow'   { if ($cursor -gt 0) { $cursor-- } }
            'DownArrow' { if ($cursor -lt ($n - 1)) { $cursor++ } }
            'Spacebar'  { $selecionado[$cursor] = -not $selecionado[$cursor] }
            'A'         {
                $todosMarcados = $true
                for ($i = 0; $i -lt $n; $i++) { if (-not $selecionado[$i]) { $todosMarcados = $false } }
                for ($i = 0; $i -lt $n; $i++) { $selecionado[$i] = -not $todosMarcados }
            }
            'Enter'     {
                Clear-Host
                $resultado = @()
                for ($i = 0; $i -lt $n; $i++) { if ($selecionado[$i]) { $resultado += $Itens[$i].Id } }
                return $resultado
            }
        }
    }
}

function Show-ResumoFinal {
    param([string[]]$Executados)
    $script:Stopwatch.Stop()
    $ts = $script:Stopwatch.Elapsed

    Write-Host ""
    Write-Host "================ RESUMO ================" -ForegroundColor Green
    foreach ($item in $Executados) {
        Write-Host "  [x] $item" -ForegroundColor Green
    }
    Write-Host ("Tempo total: {0}m{1}s" -f [int]$ts.TotalMinutes, $ts.Seconds) -ForegroundColor White
    Write-Host "=========================================" -ForegroundColor Green
}
