function Set-CustomizacaoVisual {
    Write-Info "Aplicando tema escuro e ajustes do Explorer..."

    $personalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    New-Item -Path $personalizeKey -Force | Out-Null
    Set-ItemProperty -Path $personalizeKey -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $personalizeKey -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force

    $explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $explorerKey -Name "HideFileExt" -Value 0 -Type DWord -Force

    # Menu Iniciar/ícones da barra de tarefas centralizados (só existe/faz
    # efeito no Windows 11; ignorado silenciosamente no Windows 10).
    Set-ItemProperty -Path $explorerKey -Name "TaskbarAl" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Esconde a barra/ícone de pesquisa da barra de tarefas por padrão
    # (o Widgets fica, não é tocado aqui).
    $searchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    New-Item -Path $searchKey -Force | Out-Null
    Set-ItemProperty -Path $searchKey -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force

    # Desliga a seção "Recomendado" do menu Iniciar (arquivos recentes, dicas
    # e apps promovidos) - política de máquina + os dois toggles por usuário
    # que ainda existem por baixo dela.
    $explorerPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    New-Item -Path $explorerPolicyKey -Force | Out-Null
    Set-ItemProperty -Path $explorerPolicyKey -Name "HideRecommendedSection" -Value 1 -Type DWord -Force

    Set-ItemProperty -Path $explorerKey -Name "Start_TrackDocs" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $explorerKey -Name "Start_IrisRecommendations" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # SearchHost.exe é quem de fato renderiza a caixa de pesquisa da barra de
    # tarefas - só reiniciar o Explorer não é suficiente, o valor antigo
    # (cacheado) volta sozinho se esse processo continuar de pé. Reinicia
    # também o StartMenuExperienceHost para a política de "Recomendado" valer
    # já nesta sessão, sem precisar de logoff.
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Stop-Process -Name SearchHost -Force -ErrorAction SilentlyContinue
    Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer.exe

    Write-Sucesso "Tema escuro, extensões de arquivo visíveis, menu centralizado, barra de pesquisa oculta e recomendações do menu Iniciar desativadas."
}

Register-Modulo -Id "customizacao_windows" -Titulo "Customização visual do Windows" `
    -Descricao "Tema escuro, mostrar extensões de arquivo, menu Iniciar centralizado, ocultar barra de pesquisa e desativar recomendações do menu Iniciar (Widgets fica)" `
    -Funcao ${function:Set-CustomizacaoVisual}
