function Initialize-Ambiente {
    Write-Info "Preparando o ambiente (winget, NuGet, PSGallery)..."

    winget source update | Out-Null

    # Necessário para o Install-Module do módulo de Windows Update (PSGallery
    # depende do provider NuGet) e evita o prompt "não confiável" a cada uso.
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    Write-Sucesso "Ambiente preparado."
}

Register-Modulo -Id "bootstrap" -Titulo "Preparar ambiente" `
    -Descricao "Atualiza fontes do winget e prepara NuGet/PSGallery para os demais módulos" `
    -Funcao ${function:Initialize-Ambiente}
