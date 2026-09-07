function Install-ComunicacaoMidia {
    Write-Info "Instalando Telegram, Vesktop (Discord + Vencord), Spotify, VLC e OBS Studio..."
    foreach ($app in $script:AppsComunicacaoMidia) {
        Install-WingetApp -Id $app.Id -Nome $app.Nome | Out-Null
    }
    Write-Sucesso "Apps de comunicação e mídia instalados."
}

Register-Modulo -Id "comunicacao_midia" -Titulo "Comunicação e mídia" `
    -Descricao "Telegram, Vesktop (Discord com Vencord já embutido), Spotify, VLC e OBS Studio" `
    -Funcao ${function:Install-ComunicacaoMidia}
