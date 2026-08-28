function Install-AtualizacoesWindows {
    Write-Info "Instalando o módulo PSWindowsUpdate e buscando atualizações..."

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    }
    Import-Module PSWindowsUpdate

    $updates = Get-WindowsUpdate -AcceptAll -ErrorAction SilentlyContinue
    if (-not $updates) {
        Write-Sucesso "Nenhuma atualização pendente."
        return
    }

    # AutoReboot:$false de propósito - reiniciar sozinho no meio da lista de
    # módulos derrubaria a execução dos módulos seguintes. Avisamos no final.
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false | Out-Null

    if (Get-WURebootStatus -Silent) {
        Write-Aviso "Atualizações instaladas: é necessário reiniciar o Windows para concluir (reinicie ao final deste script)."
    } else {
        Write-Sucesso "Atualizações do Windows instaladas."
    }
}

Register-Modulo -Id "windows_update" -Titulo "Atualizar o Windows" `
    -Descricao "Instala o módulo PSWindowsUpdate e aplica as atualizações pendentes do Windows Update" `
    -Funcao ${function:Install-AtualizacoesWindows}
