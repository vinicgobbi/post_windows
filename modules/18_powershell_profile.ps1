function Set-PerfilPowerShell {
    Write-Info "Instalando Oh My Posh e configurando o perfil do PowerShell..."
    # Equivalente ao Zsh + Oh My Zsh do Linux, mas nativo do Windows (sem WSL).
    Install-WingetApp -Id "JanDeDobbeleer.OhMyPosh" -Nome "Oh My Posh" | Out-Null
    Update-SessionPath

    if (Test-CommandExists "oh-my-posh") {
        oh-my-posh font install CascadiaCode
    }

    Add-LinhaAoPerfil -Linha 'oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression'

    Write-Aviso "Configure a fonte 'CascadiaCode Nerd Font' no seu terminal (Windows Terminal: Configurações > Perfil > Aparência > Fonte) para os ícones do tema aparecerem certo."
    Write-Sucesso "Perfil do PowerShell configurado com Oh My Posh."
}

Register-Modulo -Id "powershell_profile" -Titulo "Configurar perfil do PowerShell" `
    -Descricao "Oh My Posh + fonte Nerd Font + prompt no perfil do PowerShell (equivalente ao Zsh/Oh My Zsh)" `
    -Funcao ${function:Set-PerfilPowerShell}
