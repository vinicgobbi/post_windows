function Install-RustTools {
    Write-Info "Instalando rustup, eza e topgrade..."
    # Diferente do Linux, eza e topgrade já têm binário nativo pré-compilado
    # no winget - não precisa de toolchain C nem compilar via cargo.
    Install-WingetApp -Id "Rustlang.Rustup" -Nome "rustup" | Out-Null
    Install-WingetApp -Id "eza-community.eza" -Nome "eza" | Out-Null
    Install-WingetApp -Id "topgrade-rs.topgrade" -Nome "topgrade" | Out-Null
    Update-SessionPath
    Write-Sucesso "rustup, eza e topgrade instalados."
}

Register-Modulo -Id "rust_tools" -Titulo "Instalar Rust, eza e topgrade" `
    -Descricao "rustup e os binários nativos de eza e topgrade (sem precisar compilar)" `
    -Funcao ${function:Install-RustTools}
