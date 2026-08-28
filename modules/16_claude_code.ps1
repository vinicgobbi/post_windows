function Install-ClaudeCodeApp {
    Install-WingetApp -Id "Anthropic.ClaudeCode" -Nome "Claude Code" | Out-Null
}

Register-Modulo -Id "claude_code" -Titulo "Instalar Claude Code" `
    -Descricao "CLI oficial da Anthropic para desenvolvimento assistido por IA no terminal" `
    -Funcao ${function:Install-ClaudeCodeApp}
