function Install-FerramentasDev {
    Write-Info "Instalando VSCode, Docker Desktop, DBeaver, Postman e DevToys..."
    foreach ($app in $script:AppsDevTools) {
        Install-WingetApp -Id $app.Id -Nome $app.Nome | Out-Null
    }

    Write-Info "Instalando fnm e Node.js LTS..."
    Install-WingetApp -Id "Schniz.fnm" -Nome "fnm (Fast Node Manager)" | Out-Null
    Update-SessionPath

    fnm install --lts
    $versaoAtual = (fnm current).Trim()
    if ($versaoAtual -and $versaoAtual -ne "none") {
        fnm default $versaoAtual
    }

    # Precisa estar no perfil (não só na sessão atual) para o "node"/"npm"
    # funcionarem em terminais novos, igual ao "eval fnm env" no .zshrc do Linux.
    Add-LinhaAoPerfil -Linha 'fnm env --use-on-cd | Out-String | Invoke-Expression'

    Write-Sucesso "Ferramentas de desenvolvimento instaladas."
}

Register-Modulo -Id "dev_tools" -Titulo "Instalar ferramentas de desenvolvimento" `
    -Descricao "VSCode, Docker Desktop, DBeaver, Postman, DevToys e fnm/Node.js LTS" `
    -Funcao ${function:Install-FerramentasDev}
