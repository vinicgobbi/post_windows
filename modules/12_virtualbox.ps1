function Install-VirtualBoxApp {
    Write-Info "Instalando o VirtualBox..."

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if (-not $cpu.VirtualizationFirmwareEnabled) {
        Write-Aviso "Virtualização por hardware (VT-x/AMD-V) não está habilitada na BIOS/UEFI - o VirtualBox pode não funcionar direito."
    }

    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($hyperv -and $hyperv.State -eq "Enabled") {
        Write-Aviso "O Hyper-V está habilitado neste Windows. O VirtualBox roda em cima do Hyper-V (via API do Windows), o que costuma funcionar mas pode reduzir a performance comparado a rodar sem o Hyper-V."
    }

    Install-WingetApp -Id "Oracle.VirtualBox" -Nome "VirtualBox" | Out-Null
    Write-Sucesso "VirtualBox instalado."
}

Register-Modulo -Id "virtualbox" -Titulo "Instalar VirtualBox" `
    -Descricao "Gerenciador de máquinas virtuais VirtualBox (equivalente ao GNOME Boxes/virt-manager)" `
    -Funcao ${function:Install-VirtualBoxApp}
