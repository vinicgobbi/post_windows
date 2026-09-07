function Optimize-Desempenho {
    Write-Info "Aplicando otimizações de desempenho (sem mexer em efeitos visuais)..."

    # --- Delivery Optimization: restringe P2P de updates à rede local -----
    # Por padrão o Windows pode enviar/baixar atualizações de/para outros PCs
    # pela internet inteira, consumindo disco e banda em segundo plano à toa.
    $doKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    New-Item -Path $doKey -Force | Out-Null
    Set-ItemProperty -Path $doKey -Name "DODownloadMode" -Value 1 -Type DWord -Force

    # --- Storage Sense: liga o interruptor mestre --------------------------
    # Comportamento padrão: limpa temporários quando o disco está enchendo.
    $storageSenseKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    New-Item -Path $storageSenseKey -Force | Out-Null
    Set-ItemProperty -Path $storageSenseKey -Name "01" -Value 1 -Type DWord -Force

    # --- Edge Startup Boost: desliga o pré-carregamento em segundo plano ---
    $edgeKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    New-Item -Path $edgeKey -Force | Out-Null
    Set-ItemProperty -Path $edgeKey -Name "StartupBoostEnabled" -Value 0 -Type DWord -Force
    Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty |
        Where-Object { $_.Name -like "MicrosoftEdgeAutoLaunch_*" } |
        ForEach-Object { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name $_.Name -ErrorAction SilentlyContinue }

    # --- Remove apps pesados do startup (o usuário abre quando precisar) ---
    # Docker Desktop sobe uma VM WSL2 inteira no boot; Steam/GOG Galaxy só
    # atrasam a inicialização sem necessidade real de abrir sozinhos.
    foreach ($nome in @("Docker Desktop", "Steam", "GalaxyClient", "GogGalaxy")) {
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name $nome -ErrorAction SilentlyContinue
    }

    # --- Para de indexar o conteúdo da pasta de projetos --------------------
    # node_modules, .git, target/ etc. não precisam ter o CONTEÚDO indexado
    # para busca; isso só gera I/O de disco em segundo plano à toa.
    $projPath = "$env:USERPROFILE\Projects"
    if (Test-Path $projPath) {
        $item = Get-Item $projPath -Force
        $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::NotContentIndexed
    }

    # --- Exclusões do Windows Defender para pastas de dev pesadas ----------
    # Só exclui o que de fato existir nesta máquina (reflete o que os outros
    # módulos já instalaram até aqui: rust_tools, dev_tools).
    $exclusoes = @(
        $projPath,
        "$env:USERPROFILE\.cargo",
        "$env:USERPROFILE\.rustup",
        "$env:LOCALAPPDATA\Docker",
        "$env:ProgramData\DockerDesktop"
    )
    foreach ($caminho in $exclusoes) {
        if (Test-Path $caminho) {
            Add-MpPreference -ExclusionPath $caminho -ErrorAction SilentlyContinue
        }
    }

    # --- Energia: desempenho máximo na tomada, economia na bateria ---------
    # Ajusta o plano ATIVO (não troca de plano) para diferenciar AC de DC,
    # em vez de forçar "Alto Desempenho" fixo e comer bateria sem necessidade.
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 2>&1 | Out-Null
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1 | Out-Null
    powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null

    # SysMain (Superfetch) fica intocado de propósito: desligar é um mito
    # antigo de "acelerar SSD" - a própria Microsoft recomenda manter ligado,
    # ele ajuda no cache de apps usados com frequência mesmo em SSD/NVMe.

    # --- Hibernação: desliga só em desktop -----------------------------
    # hiberfil.sys ocupa espaço em disco proporcional à RAM (vários GB) sem
    # servir pra nada numa máquina que não hiberna de verdade. Desligar
    # também desativa o Fast Startup (que depende do hiberfil.sys), o que
    # não é problema aqui: sem hibernação, Fast Startup não faz sentido de
    # qualquer forma. Só mexe em desktop - notebook depende de hibernar ao
    # fechar a tampa/ficar sem bateria.
    if (Test-EhNotebook) {
        Write-Info "Notebook detectado: mantendo hibernação ligada (fechar a tampa/bateria fraca dependem dela)."
    } else {
        powercfg /hibernate off 2>&1 | Out-Null
        Write-Sucesso "Hibernação desligada (desktop detectado) - libera o espaço do hiberfil.sys."
    }

    Write-Sucesso "Otimizações de desempenho aplicadas (Delivery Optimization, Storage Sense, Edge Startup Boost, startup do Docker/Steam/GOG, indexação, exclusões do Defender, energia e hibernação)."
}

Register-Modulo -Id "performance" -Titulo "Otimizações de desempenho" `
    -Descricao "Delivery Optimization, Storage Sense, remove apps pesados do startup, exclusões do Defender para pastas de dev, energia AC/DC e hibernação (desktop) - sem mexer em efeitos visuais" `
    -Funcao ${function:Optimize-Desempenho}
