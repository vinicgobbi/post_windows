function Install-Bitwarden {
    Install-WingetApp -Id "Bitwarden.Bitwarden" -Nome "Bitwarden" | Out-Null
}

Register-Modulo -Id "bitwarden" -Titulo "Instalar Bitwarden" `
    -Descricao "Cliente desktop nativo do Bitwarden" `
    -Funcao ${function:Install-Bitwarden}
