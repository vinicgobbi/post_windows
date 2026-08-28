# ==========================================
# Configuração compartilhada - catálogo de apps
# ==========================================
# Cada entrada é um id do winget (App Id) confirmado com "winget search"
# nesta máquina. "ChocoFallback" só aparece nos poucos apps sem pacote no
# winget - Install-WingetApp cai pro Chocolatey automaticamente nesses casos.

$script:AppsNavegadorGit = @(
    @{ Id = "Google.Chrome"; Nome = "Google Chrome" }
    @{ Id = "Git.Git"; Nome = "Git" }
    @{ Id = "Git.GCM"; Nome = "Git Credential Manager" }
)

$script:AppsDevTools = @(
    @{ Id = "Microsoft.VisualStudioCode"; Nome = "Visual Studio Code" }
    @{ Id = "Docker.DockerDesktop"; Nome = "Docker Desktop" }
    @{ Id = "DBeaver.DBeaver.Community"; Nome = "DBeaver CE" }
    @{ Id = "Postman.Postman"; Nome = "Postman" }
    # O pacote "DevToys-app.DevToys" do winget é a build preview (2.0-preview.x)
    # apesar do nome não deixar isso claro - "9PGCV4V3BK4W" é a estável de
    # verdade (1.0.x), vem da Microsoft Store.
    @{ Id = "9PGCV4V3BK4W"; Nome = "DevToys" }
)

$script:AppsComunicacaoMidia = @(
    @{ Id = "Telegram.TelegramDesktop"; Nome = "Telegram" }
    @{ Id = "Vencord.Vesktop"; Nome = "Vesktop (Discord + Vencord já embutido)" }
    @{ Id = "Spotify.Spotify"; Nome = "Spotify" }
    @{ Id = "VideoLAN.VLC"; Nome = "VLC" }
    @{ Id = "OBSProject.OBSStudio"; Nome = "OBS Studio" }
)

$script:AppsProdutividade = @(
    @{ Id = "Obsidian.Obsidian"; Nome = "Obsidian" }
    @{ Id = "ente-io.auth-desktop"; Nome = "Ente Auth" }
    @{ Id = "gaphor.gaphor"; Nome = "Gaphor" }
)

$script:AppsUtilitariosRede = @(
    @{ Id = "Mikrotik.Winbox"; Nome = "WinBox" }
    @{ Id = "qBittorrent.qBittorrent"; Nome = "qBittorrent" }
    @{ Id = "FileZilla"; Nome = "FileZilla Client"; ChocoFallback = "filezilla" }
)

# Product ID usado pelo Office Deployment Tool (módulo 04_office). Padrão
# para assinaturas de negócio/enterprise do Microsoft 365 Apps. Se a sua
# licença for Microsoft 365 Personal/Family, troque para "O365HomePremRetail".
$script:OfficeProductId = "O365ProPlusRetail"

# Repo de dotfiles pessoal (módulo 18_powershell_profile) - de onde vem a
# config do Oh My Posh (tema "detail", aliases, editor). Troque se for fork
# ou repo próprio diferente.
$script:DotfilesRepoUrl = "https://github.com/vinicgobbi/Dotfiles.git"

$script:AppsJogos = @(
    @{ Id = "Valve.Steam"; Nome = "Steam" }
    @{ Id = "HeroicGamesLauncher.HeroicGamesLauncher"; Nome = "Heroic Games Launcher" }
    @{ Id = "EpicGames.EpicGamesLauncher"; Nome = "Epic Games Launcher" }
    @{ Id = "GOG.Galaxy"; Nome = "GOG Galaxy" }
    @{ Id = "PrismLauncher.PrismLauncher"; Nome = "Prism Launcher" }
)

# ==========================================
# Apps do inventário Linux sem equivalente/necessidade no Windows
# ==========================================
# - Flatseal, ExtensionManager, Ignition, Warehouse: gerenciam Flatpak, que
#   não existe no Windows.
# - Mission Center: substituído pelo Gerenciador de Tarefas nativo.
# - Remmina: RDP já é nativo via mstsc (Conexão de Área de Trabalho Remota);
#   sem cliente VNC nativo equivalente, avise se precisar disso no futuro.
# - ProtonPlus: gerencia versões do Proton (compatibilidade Windows->Linux),
#   sem sentido no Windows, onde os jogos rodam .exe nativo.
# - LibreOffice/OnlyOffice: substituídos pelo Microsoft 365 Apps (módulo 04).
