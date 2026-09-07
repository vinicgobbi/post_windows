function Install-Jogos {
    Write-Info "Instalando Steam, Heroic, Epic Games Launcher, GOG Galaxy e Prism Launcher..."
    foreach ($app in $script:AppsJogos) {
        Install-WingetApp -Id $app.Id -Nome $app.Nome | Out-Null
    }
    Write-Sucesso "Launchers de jogos instalados."
}

Register-Modulo -Id "jogos" -Titulo "Instalar launchers de jogos" `
    -Descricao "Steam, Heroic Games Launcher, Epic Games Launcher, GOG Galaxy e Prism Launcher (Minecraft)" `
    -Funcao ${function:Install-Jogos}
