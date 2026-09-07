function Install-Produtividade {
    Write-Info "Instalando Obsidian, Ente Auth e Gaphor..."
    foreach ($app in $script:AppsProdutividade) {
        Install-WingetApp -Id $app.Id -Nome $app.Nome | Out-Null
    }
    Write-Sucesso "Apps de produtividade instalados."
}

Register-Modulo -Id "produtividade" -Titulo "Produtividade" `
    -Descricao "Obsidian, Ente Auth (2FA) e Gaphor" `
    -Funcao ${function:Install-Produtividade}
