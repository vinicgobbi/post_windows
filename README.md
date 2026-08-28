# POST — Script de pós-instalação (Windows)

Script modular para configurar uma workstation Windows recém-instalada:
Chrome, Git + Git Credential Manager, Microsoft 365 Apps (no lugar do
LibreOffice/OnlyOffice), VSCode, Docker Desktop, DBeaver, Postman, DevToys,
fnm/Node.js, PHP + driver SQL Server, Bitwarden, Telegram, Vesktop
(Discord+Vencord), Spotify, VLC, OBS Studio, Obsidian, Ente Auth, Gaphor,
jogos (Steam, Heroic, Epic Games Launcher, GOG Galaxy, Prism Launcher),
WinBox, qBittorrent, FileZilla, VirtualBox, Tailscale, Logi Options+,
importação de perfis OpenVPN, Claude Code, Rust (rustup, eza, topgrade),
Oh My Posh (perfil do PowerShell), customização/debloat do Windows e
otimizações de desempenho (sem mexer em efeitos visuais).

Contraparte do [`post_install`](../post_install) (Linux), adaptada às
diferenças reais do Windows — ver "Limitações conhecidas" no final.

## Como usar

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

Não precisa abrir como Administrador antes: o script detecta que não está
elevado e se reabre sozinho pedindo o UAC. O fluxo é:

1. Detecta a versão/edição do Windows e mostra o que foi identificado.
2. Abre um **menu interativo de checklist** com todos os módulos, já
   marcados por padrão:
   - `↑` / `↓` — mover o cursor
   - `espaço` — marcar/desmarcar o módulo atual
   - `a` — marcar/desmarcar todos de uma vez
   - `enter` — confirmar a seleção
3. Mostra um resumo dos módulos escolhidos e pede confirmação (`s/N`) antes
   de começar.
4. Executa cada módulo selecionado, na ordem correta de dependência,
   exibindo `[passo/total] nome do módulo`.
5. No final, mostra um resumo com os módulos executados e o tempo total.

Se o script for executado de forma não interativa (entrada/saída
redirecionada, ou fora de um console real), o menu é pulado automaticamente
e **todos** os módulos rodam, com um aviso.

Diferente do Linux, o Windows não separa "usuário root" de "usuário
desktop": a elevação por UAC não troca de conta, então a configuração é
sempre aplicada a quem está rodando o script — não há uma pergunta "para
qual usuário configurar".

## Log em arquivo

Cada execução grava dois arquivos em `logs/` (criada na raiz do repo,
ignorada pelo git):

- `setup_<timestamp>.log` — só as mensagens Info/Aviso/Erro/Sucesso/Passo,
  com hora e nível. Bom para uma leitura rápida do que rodou.
- `setup_<timestamp>.raw.log` — transcript bruto (`Start-Transcript`) de
  tudo que passa pelo console durante a fase de execução dos módulos,
  incluindo a saída crua de `winget`/`choco`/`dism`. Bom para investigar o
  motivo de uma falha.

## Estrutura do projeto

```
setup.ps1                       # ponto de entrada — orquestra tudo
config.ps1                      # catálogo de apps (ids do winget)
lib/
  UI.ps1                        # cores, mensagens, menu interativo, prompts, resumo final
  SystemDetect.ps1               # detecção de versão/edição do Windows, admin, winget
  Utils.ps1                     # Install-WingetApp/Install-ChocoApp, registro de módulos, resolução de dependências
modules/
  01_bootstrap.ps1              # atualiza fontes do winget, prepara NuGet/PSGallery
  02_windows_update.ps1         # PSWindowsUpdate + instala atualizações pendentes
  03_navegador_git.ps1          # Chrome, Git, Git Credential Manager
  04_office.ps1                 # Microsoft 365 Apps via Office Deployment Tool
  05_dev_tools.ps1              # VSCode, Docker Desktop, DBeaver, Postman, DevToys, fnm/Node
  06_php_sqlsrv.ps1             # PHP, driver ODBC 18 e extensões sqlsrv/pdo_sqlsrv
  07_bitwarden.ps1
  08_comunicacao_midia.ps1      # Telegram, Vesktop, Spotify, VLC, OBS Studio
  09_produtividade.ps1          # Obsidian, Ente Auth, Gaphor
  10_jogos.ps1                  # Steam, Heroic, Epic Games Launcher, GOG Galaxy, Prism Launcher
  11_utilitarios_rede.ps1       # WinBox, qBittorrent, FileZilla (Chocolatey)
  12_virtualbox.ps1
  13_tailscale.ps1
  14_logitech_options.ps1       # Logi Options+ (equivalente ao Solaar)
  15_ovpn.ps1                   # OpenVPN GUI + importa perfis de ./OVPN
  16_claude_code.ps1
  17_rust_tools.ps1             # rustup, eza, topgrade (binários nativos, sem compilar)
  18_powershell_profile.ps1     # Oh My Posh no perfil do PowerShell (equivalente ao Zsh/Oh My Zsh)
  19_customizacao_windows.ps1   # tema escuro, extensões de arquivo, barra de tarefas
  20_performance.ps1            # Delivery Optimization, Storage Sense, startup, Defender, energia
  21_debloat.ps1                # remove bloatware e sugestões do Windows
  22_limpeza.ps1                # limpa temporários e cache do Chocolatey
OVPN/                           # coloque aqui os .ovpn a importar (ver OVPN/README.md)
```

Cada arquivo em `modules/` define uma função e termina chamando
`Register-Modulo -Id ... -Titulo ... -Descricao ... -Funcao ${function:Nome}`,
que é como o módulo "se anuncia" para aparecer no menu — não precisa editar
o `setup.ps1` para adicionar/remover etapas, só criar ou apagar o arquivo em
`modules/` (o prefixo numérico define a ordem de execução).

## winget e Chocolatey

`winget` é o gerenciador principal (equivalente ao `apt`/`dnf` do Linux).
Quando um app não tem pacote no winget (ex.: FileZilla), `Install-WingetApp`
cai automaticamente para o Chocolatey (instalado sob demanda, só na primeira
vez que isso acontecer) — a ideia é sempre tentar automatizar, mesmo fora da
"loja" principal, como pedido.

## Requisitos

- Windows 10 2004+ (build 19041) ou Windows 11, com `winget` disponível
  (App Installer da Microsoft Store atualizado).
- PowerShell 5.1+ (já vem no Windows) — não precisa do PowerShell 7.
- Conta com direitos de Administrador (o script se autoeleva via UAC).
- Conta Microsoft 365 ativa para o módulo de Office ativar depois de
  instalado (o ODT baixa e instala, mas não ativa a licença sozinho).

## Limitações conhecidas

- **Sem Flatpak**: a maioria dos apps continua sendo instalador nativo
  (exe/msi) via winget; alguns manifests da comunidade têm qualidade
  variável — se um app parar de instalar silenciosamente, é o primeiro
  lugar para investigar.
- **Execution Policy**: por padrão o Windows bloqueia scripts `.ps1`; por
  isso o comando de uso inclui `-ExecutionPolicy Bypass`.
- **Reboots no meio do processo**: o módulo de Windows Update instala tudo
  com `-IgnoreReboot` de propósito (para não derrubar os módulos
  seguintes), mas avisa no final se for necessário reiniciar.
- **UAC residual**: mesmo com o script elevado, alguns instaladores ainda
  podem abrir o próprio prompt de UAC — não é 100% garantido zero
  interação para todo app.
- **Edição do Windows**: alguns recursos (Hyper-V, `gpedit.msc`) só
  existem em Pro/Enterprise/Education — este script usa VirtualBox em vez
  de Hyper-V justamente para funcionar em qualquer edição, inclusive Home.
- **Licenciamento do Office**: o módulo `04_office` instala os apps, mas a
  ativação da licença (login com a conta Microsoft 365) é manual — não dá
  para automatizar sem guardar credenciais no script.
- **sqlsrv/pdo_sqlsrv**: as DLLs são baixadas da release mais recente do
  [`microsoft/msphpsql`](https://github.com/microsoft/msphpsql) no GitHub;
  se a Microsoft mudar a convenção de nomes dos arquivos, o módulo avisa e
  pula em vez de falhar silenciosamente.
