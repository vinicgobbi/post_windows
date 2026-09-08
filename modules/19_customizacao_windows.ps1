function Set-CustomizacaoVisual {
    Write-Info "Aplicando tema escuro e ajustes do Explorer..."

    $personalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    New-Item -Path $personalizeKey -Force | Out-Null
    Set-ItemProperty -Path $personalizeKey -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $personalizeKey -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force

    # Garante que os efeitos de transparência/blur (Configurações >
    # Personalização > Cores > "Efeitos de transparência") continuem
    # ligados - esta chave nunca é mexida por este script para desligar
    # nada; setar explicitamente é só reforço, caso o valor já viesse
    # desligado de fábrica/perfil.
    Set-ItemProperty -Path $personalizeKey -Name "EnableTransparency" -Value 1 -Type DWord -Force

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

    # Avisa o shell da troca de tema pelo mesmo mecanismo que o app
    # Configurações usa (broadcast de WM_SETTINGCHANGE/"ImmersiveColorSet"),
    # em vez de depender só do restart forçado do Explorer logo abaixo para
    # o DWM recompor o tema. Matar explorer/SearchHost/StartMenuExperienceHost
    # à força sem isso pode deixar a composição (blur/transparência) num
    # estado inconsistente até o usuário reabrir a sessão ou alternar a
    # opção manualmente - mesmo com "EnableTransparency" continuando em 1.
    if (-not ("Win32.NativeMethods" -as [type])) {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    }
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1A
    $SMTO_ABORTIFHUNG = 0x2
    [UIntPtr]$resultado = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "ImmersiveColorSet", $SMTO_ABORTIFHUNG, 2000, [ref]$resultado) | Out-Null

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

    Write-Sucesso "Tema escuro (efeitos de transparência/blur mantidos), extensões de arquivo visíveis, menu centralizado, barra de pesquisa oculta e recomendações do menu Iniciar desativadas."
}

Register-Modulo -Id "customizacao_windows" -Titulo "Customização visual do Windows" `
    -Descricao "Tema escuro, mostrar extensões de arquivo, menu Iniciar centralizado, ocultar barra de pesquisa e desativar recomendações do menu Iniciar (Widgets fica)" `
    -Funcao ${function:Set-CustomizacaoVisual}
