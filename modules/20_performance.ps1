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

    # --- Desliga os serviços de telemetria (DiagTrack + dmwappushsvc) ------
    # As tarefas agendadas de diagnóstico já são desligadas acima, mas os
    # SERVIÇOS continuam ativos e geram I/O de disco/rede periódico em
    # segundo plano. "Connected User Experiences and Telemetry" (DiagTrack) e
    # "WAP Push Message Routing Service" (dmwappushsvc) não têm efeito
    # percebido no dia a dia com o nível de telemetria padrão do Windows.
    foreach ($servico in @("DiagTrack", "dmwappushsvc")) {
        if (Get-Service -Name $servico -ErrorAction SilentlyContinue) {
            Stop-Service -Name $servico -Force -ErrorAction SilentlyContinue
            Set-Service -Name $servico -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    # --- Restringe apps em segundo plano ------------------------------------
    # Por padrão apps UWP (incl. Xbox remanescente, Office, Copilot) podem
    # continuar rodando/atualizando minimizados, consumindo CPU/rede à toa.
    # Política "Let Windows apps run in the background" = 2 (negar à força) +
    # o toggle legado equivalente, para cobrir builds mais antigas do Win10/11.
    $appPrivacyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
    New-Item -Path $appPrivacyKey -Force | Out-Null
    Set-ItemProperty -Path $appPrivacyKey -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force

    $backgroundAppsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    New-Item -Path $backgroundAppsKey -Force | Out-Null
    Set-ItemProperty -Path $backgroundAppsKey -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force

    # --- NTFS: para de gravar o timestamp de último acesso ------------------
    # Por padrão o NTFS atualiza um timestamp a cada arquivo LIDO (não só
    # escrito) - é I/O de disco puro e desnecessário para quase todo uso.
    fsutil behavior set disablelastaccess 1 | Out-Null

    # --- Garante que o TRIM do SSD está ativo -------------------------------
    # Sem isso a velocidade de escrita do SSD degrada ao longo do tempo;
    # geralmente já vem certo por padrão, mas reforça explicitamente. Não faz
    # diferença em HDD - o Windows só manda TRIM para discos que suportam.
    fsutil behavior set disabledeletenotify 0 | Out-Null

    # --- Cria a pasta de Projetos e fixa no Acesso Rápido -------------------
    # Equivalente ao "xdg-user-dirs-update --set PROJECTS" + bookmark no
    # gerenciador de arquivos do lado Linux (ver ambiente_usuario.sh). Sem
    # isso a pasta nunca existia de verdade e a exclusão de indexação/Defender
    # logo abaixo nunca tinha efeito (dependiam de um Test-Path que sempre
    # dava falso).
    $projPath = "$env:USERPROFILE\Projects"
    New-Item -ItemType Directory -Force -Path $projPath | Out-Null

    try {
        $shellApp = New-Object -ComObject Shell.Application
        # "PinToHome" é um verbo interno estável (funciona independente do
        # idioma do Windows, ao contrário de tentar clicar no texto "Fixar no
        # Acesso Rápido" do menu de contexto).
        $shellApp.Namespace($projPath).Self.InvokeVerb("PinToHome")
        [Runtime.Interopservices.Marshal]::ReleaseComObject($shellApp) | Out-Null
    } catch {
        Write-Aviso "Não consegui fixar $projPath no Acesso Rápido do Explorer."
    }

    # --- Para de indexar o conteúdo da pasta de projetos --------------------
    # node_modules, .git, target/ etc. não precisam ter o CONTEÚDO indexado
    # para busca; isso só gera I/O de disco em segundo plano à toa.
    $item = Get-Item $projPath -Force
    $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::NotContentIndexed

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

    Write-Sucesso "Otimizações de desempenho aplicadas (Delivery Optimization, Storage Sense, Edge Startup Boost, startup do Docker/Steam/GOG, telemetria, apps em segundo plano, NTFS/TRIM, indexação, exclusões do Defender, energia e hibernação)."
}

Register-Modulo -Id "performance" -Titulo "Otimizações de desempenho" `
    -Descricao "Cria e fixa a pasta Projects no Acesso Rápido, Delivery Optimization, Storage Sense, remove apps pesados do startup, desliga telemetria (DiagTrack) e apps em segundo plano, NTFS sem timestamp de acesso, TRIM do SSD, exclusões do Defender/indexação para pastas de dev, energia AC/DC e hibernação (desktop) - sem mexer em efeitos visuais" `
    -Funcao ${function:Optimize-Desempenho}
