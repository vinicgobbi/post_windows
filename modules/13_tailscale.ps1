function Install-TailscaleApp {
    Write-Info "Instalando o Tailscale..."
    # O cliente Windows já vem com ícone de bandeja e app gráfico completos -
    # diferente do Linux, não precisa de um "Trayscale" separado.
    Install-WingetApp -Id "Tailscale.Tailscale" -Nome "Tailscale" | Out-Null
    Write-Aviso "Abra o Tailscale pelo ícone da bandeja e faça login para conectar este PC à sua tailnet (login é interativo, não dá pra automatizar)."
}

Register-Modulo -Id "tailscale" -Titulo "Instalar Tailscale" `
    -Descricao "Tailscale (VPN mesh) com o cliente gráfico nativo do Windows" `
    -Funcao ${function:Install-TailscaleApp}
