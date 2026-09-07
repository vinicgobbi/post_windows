function Install-NavegadorGit {
    Write-Info "Instalando Chrome, Git e Git Credential Manager..."
    foreach ($app in $script:AppsNavegadorGit) {
        Install-WingetApp -Id $app.Id -Nome $app.Nome | Out-Null
    }
    Write-Sucesso "Chrome, Git e GCM instalados."
}

Register-Modulo -Id "navegador_git" -Titulo "Chrome + Git + Git Credential Manager" `
    -Descricao "Instala o Google Chrome, o Git e o Git Credential Manager" `
    -Funcao ${function:Install-NavegadorGit}
