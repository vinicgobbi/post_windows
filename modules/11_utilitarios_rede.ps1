function Install-UtilitariosRede {
    Write-Info "Instalando WinBox, qBittorrent e FileZilla..."
    foreach ($app in $script:AppsUtilitariosRede) {
        $chocoFallback = $null
        if ($app.ContainsKey("ChocoFallback")) { $chocoFallback = $app.ChocoFallback }
        Install-WingetApp -Id $app.Id -Nome $app.Nome -ChocoFallback $chocoFallback | Out-Null
    }
    Write-Sucesso "Utilitários de rede instalados."
}

Register-Modulo -Id "utilitarios_rede" -Titulo "Utilitários de rede" `
    -Descricao "WinBox, qBittorrent e FileZilla Client (via Chocolatey, sem pacote no winget)" `
    -Funcao ${function:Install-UtilitariosRede}
