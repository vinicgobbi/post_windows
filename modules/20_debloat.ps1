function Remove-BloatwareWindows {
    Write-Info "Removendo apps pré-instalados não usados e ajustando sugestões do Windows..."

    # Lista conservadora - só o que praticamente ninguém usa depois de trocar
    # por VLC/Spotify/Telegram/Office de verdade (ver config.ps1). Desmarque
    # este módulo no menu se preferir não mexer em nada disso.
    $padroes = @(
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MixedReality.Portal"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.Print3D"
        "Microsoft.3DBuilder"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "Microsoft.BingWeather"
        "Microsoft.BingNews"
        "Clipchamp.Clipchamp"
        "Microsoft.SkypeApp"
        "Microsoft.Todos"
        "Microsoft.People"
    )

    foreach ($padrao in $padroes) {
        Get-AppxPackage -AllUsers -Name $padrao -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $padrao } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }

    # Desliga a reinstalação automática de "apps sugeridos" e os anúncios do menu Iniciar.
    $cloudContentKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    New-Item -Path $cloudContentKey -Force | Out-Null
    Set-ItemProperty -Path $cloudContentKey -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force

    $contentDeliveryKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    New-Item -Path $contentDeliveryKey -Force | Out-Null
    Set-ItemProperty -Path $contentDeliveryKey -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDeliveryKey -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force

    Write-Sucesso "Bloatware removido e sugestões do Windows desativadas."
}

Register-Modulo -Id "debloat" -Titulo "Remover bloatware do Windows" `
    -Descricao "Remove apps pré-instalados pouco usados e desativa apps/anúncios sugeridos" `
    -Funcao ${function:Remove-BloatwareWindows}
