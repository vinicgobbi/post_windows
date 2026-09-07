function Import-PerfisOvpn {
    Write-Info "Instalando o OpenVPN GUI e importando perfis..."
    Install-WingetApp -Id "OpenVPNTechnologies.OpenVPN" -Nome "OpenVPN GUI" | Out-Null

    $ovpnDir = Join-Path $script:ScriptDir "OVPN"
    $arquivos = Get-ChildItem -Path $ovpnDir -Filter "*.ovpn" -ErrorAction SilentlyContinue
    if (-not $arquivos) {
        Write-Aviso "Nenhum arquivo .ovpn encontrado em $ovpnDir - pulando importação."
        return
    }

    # O OpenVPN GUI monitora esta pasta e lista cada .ovpn como um perfil
    # separado - basta copiar o arquivo pra lá (sem "nmcli import" equivalente
    # necessário; DNS/domínio do dhcp-option são aplicados automaticamente
    # pelo próprio cliente Windows).
    $configDir = Join-Path $env:ProgramFiles "OpenVPN\config"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    foreach ($arquivo in $arquivos) {
        Copy-Item -Path $arquivo.FullName -Destination $configDir -Force
        Write-Sucesso "Perfil '$($arquivo.BaseName)' importado."
    }

    Write-Aviso "Abra o OpenVPN GUI (ícone na bandeja) para conectar - conexão/autenticação é manual."
}

Register-Modulo -Id "ovpn" -Titulo "Importar perfis OpenVPN" `
    -Descricao "Instala o OpenVPN GUI e copia os .ovpn de .\OVPN para a pasta de perfis monitorada por ele" `
    -Funcao ${function:Import-PerfisOvpn}
