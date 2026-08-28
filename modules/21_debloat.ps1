function Remove-BloatwareWindows {
    Write-Info "Removendo apps pré-instalados não usados e ajustando sugestões do Windows..."

    # Lista conservadora - só o que praticamente ninguém usa depois de trocar
    # por VLC/Spotify/Telegram/Office de verdade (ver config.ps1). Desmarque
    # este módulo no menu se preferir não mexer em nada disso.
    #
    # Teams (Chat) e Widgets ficam de fora de propósito - mantidos por pedido
    # explícito. Vincular ao Celular (YourPhone) também não entra - em uso.
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
        # Família Xbox/Game Bar - sem uso de Game Pass/gravação de clipes;
        # Steam/Epic/GOG já têm overlay próprio.
        "Microsoft.GamingApp"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxGameCallableUI"
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

    # Desliga resultados da web/Bing na busca do menu Iniciar - busca fica só
    # local, sem chamada de rede a cada tecla digitada.
    $searchPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    New-Item -Path $searchPolicyKey -Force | Out-Null
    Set-ItemProperty -Path $searchPolicyKey -Name "DisableWebSearch" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $searchPolicyKey -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force

    $searchUserKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    New-Item -Path $searchUserKey -Force | Out-Null
    Set-ItemProperty -Path $searchUserKey -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $searchUserKey -Name "CortanaConsent" -Value 0 -Type DWord -Force

    # Tarefas agendadas de telemetria/diagnóstico - rodam periodicamente em
    # segundo plano sem nenhum efeito visível; ErrorAction tolera builds onde
    # a tarefa não existe (varia por versão/edição do Windows).
    $tarefas = @(
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" }
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" }
        @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" }
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" }
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" }
        @{ Path = "\Microsoft\Windows\DiskDiagnostic\"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" }
        @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClient" }
        @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClientOnScenarioDownload" }
    )
    foreach ($tarefa in $tarefas) {
        if (Get-ScheduledTask -TaskPath $tarefa.Path -TaskName $tarefa.Name -ErrorAction SilentlyContinue) {
            Disable-ScheduledTask -TaskPath $tarefa.Path -TaskName $tarefa.Name -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Write-Sucesso "Bloatware removido, sugestões do Windows/busca web desativadas e tarefas de telemetria desligadas."
}

Register-Modulo -Id "debloat" -Titulo "Remover bloatware do Windows" `
    -Descricao "Remove apps pré-instalados (incl. família Xbox/Game Bar) e desativa apps/anúncios sugeridos, busca web e tarefas de telemetria" `
    -Funcao ${function:Remove-BloatwareWindows}
