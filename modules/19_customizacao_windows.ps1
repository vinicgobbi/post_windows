function Set-CustomizacaoVisual {
    Write-Info "Aplicando tema escuro e ajustes do Explorer..."

    $personalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    New-Item -Path $personalizeKey -Force | Out-Null
    Set-ItemProperty -Path $personalizeKey -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $personalizeKey -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force

    $explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $explorerKey -Name "HideFileExt" -Value 0 -Type DWord -Force

    # Barra de tarefas alinhada à esquerda (só existe/faz efeito no Windows 11;
    # ignorado silenciosamente no Windows 10, que já é alinhado à esquerda).
    Set-ItemProperty -Path $explorerKey -Name "TaskbarAl" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer.exe

    Write-Sucesso "Tema escuro, extensões de arquivo visíveis e barra de tarefas ajustados."
}

Register-Modulo -Id "customizacao_windows" -Titulo "Customização visual do Windows" `
    -Descricao "Tema escuro, mostrar extensões de arquivo e alinhar a barra de tarefas à esquerda" `
    -Funcao ${function:Set-CustomizacaoVisual}
