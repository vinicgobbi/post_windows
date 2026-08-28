function Copy-ConfigOhMyPosh {
    # Copia só a pasta oh-my-posh/ do repo de dotfiles para uma pasta dedicada
    # (~/.config/oh-my-posh) - clona o repo num diretório temporário, copia
    # apenas o necessário e descarta o clone. É uma cópia simples (sem git),
    # de propósito: assim como no Linux, se o repo de projetos for apagado por
    # acidente, a config do prompt continua intacta. Atualizações no repo não
    # se propagam sozinhas para cá - precisa rodar este módulo de novo (ou
    # copiar manualmente) depois de mudar algo no tema/aliases.
    param([string]$Destino)

    if (-not (Test-CommandExists "git")) {
        Write-Aviso "Git não encontrado; pulando a config personalizada do Oh My Posh (fica no tema padrão)."
        return $false
    }

    $tempClone = Join-Path $env:TEMP "dotfiles-omp-$([guid]::NewGuid())"
    try {
        git clone --depth 1 --quiet $script:DotfilesRepoUrl $tempClone
        if ($LASTEXITCODE -ne 0) {
            Write-Aviso "Não consegui clonar $script:DotfilesRepoUrl; Oh My Posh fica no tema padrão."
            return $false
        }

        $origemOmp = Join-Path $tempClone "oh-my-posh"
        if (-not (Test-Path $origemOmp)) {
            Write-Aviso "O repo clonado não tem uma pasta 'oh-my-posh'; Oh My Posh fica no tema padrão."
            return $false
        }

        New-Item -Path $Destino -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $origemOmp "*") -Destination $Destino -Recurse -Force
        return $true
    } finally {
        Remove-Item -Path $tempClone -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-PerfilPowerShell {
    Write-Info "Instalando PowerShell 7, Oh My Posh e configurando os perfis..."
    # Equivalente ao Zsh + Oh My Zsh do Linux, mas nativo do Windows (sem WSL).
    Install-WingetApp -Id "Microsoft.PowerShell" -Nome "PowerShell 7" | Out-Null
    Install-WingetApp -Id "JanDeDobbeleer.OhMyPosh" -Nome "Oh My Posh" | Out-Null
    Update-SessionPath

    if (Test-CommandExists "oh-my-posh") {
        oh-my-posh font install CascadiaCode
    }

    $configDestino = "$env:USERPROFILE\.config\oh-my-posh"
    $usouConfigPessoal = Copy-ConfigOhMyPosh -Destino $configDestino

    $linhaPerfil = if ($usouConfigPessoal) {
        ". `"$configDestino\profile.ps1`""
    } else {
        'oh-my-posh init pwsh | Invoke-Expression'
    }

    # Perfil do Windows PowerShell 5.1 (o desta própria sessão do instalador).
    Add-LinhaAoPerfil -Linha $linhaPerfil

    # Perfil do PowerShell 7 - caminho próprio (pode estar redirecionado pro
    # OneDrive, por isso pede pro próprio pwsh resolver o $PROFILE dele em vez
    # de montar o caminho na mão).
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $pwshProfilePath = & $pwshCmd.Source -NoProfile -Command '$PROFILE'
        if ($pwshProfilePath) {
            Add-LinhaAoPerfil -Linha $linhaPerfil -PerfilPath $pwshProfilePath
        }
    }

    Write-Aviso "Configure a fonte 'CascadiaCode Nerd Font' no seu terminal (Windows Terminal: Configurações > Perfil > Aparência > Fonte) para os ícones do tema aparecerem certo."
    Write-Sucesso "PowerShell 7 instalado e perfis (5.1 e 7) configurados com Oh My Posh."
}

Register-Modulo -Id "powershell_profile" -Titulo "Configurar perfil do PowerShell" `
    -Descricao "PowerShell 7 + Oh My Posh com a config pessoal (tema, aliases, editor) copiada para ~\.config\oh-my-posh + fonte Nerd Font" `
    -Funcao ${function:Set-PerfilPowerShell} -Dependencias @("navegador_git")
