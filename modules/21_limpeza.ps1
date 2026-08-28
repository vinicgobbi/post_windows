function Invoke-LimpezaFinal {
    Write-Info "Limpando arquivos temporários..."

    Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "C:\Windows\Temp" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-CommandExists "choco") {
        choco cache remove --all 2>$null | Out-Null
    }

    Write-Sucesso "Limpeza concluída."
}

Register-Modulo -Id "limpeza" -Titulo "Limpeza final" `
    -Descricao "Remove arquivos temporários e o cache do Chocolatey (se instalado)" `
    -Funcao ${function:Invoke-LimpezaFinal}
