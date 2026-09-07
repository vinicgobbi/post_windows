function Install-LogiOptions {
    Install-WingetApp -Id "Logitech.OptionsPlus" -Nome "Logi Options+" | Out-Null
}

Register-Modulo -Id "logitech_options" -Titulo "Instalar Logi Options+" `
    -Descricao "Software oficial da Logitech para mouse/teclado (equivalente ao Solaar no Linux)" `
    -Funcao ${function:Install-LogiOptions}
