function Install-MicrosoftOffice {
    Write-Info "Instalando o Microsoft 365 Apps (substitui LibreOffice/OnlyOffice)..."
    Install-WingetApp -Id "Microsoft.OfficeDeploymentTool" -Nome "Office Deployment Tool" | Out-Null

    $odtDir = Join-Path $env:ProgramFiles "OfficeDeploymentTool"
    $odtExe = Join-Path $odtDir "setup.exe"
    if (-not (Test-Path $odtExe)) {
        Write-Aviso "setup.exe do ODT não encontrado em $odtDir; pulando instalação do Office."
        return
    }

    $configXml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="$($script:OfficeProductId)">
      <Language ID="MatchOS" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" />
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@
    $configPath = Join-Path $odtDir "configuration.xml"
    Set-Content -Path $configPath -Value $configXml -Encoding UTF8

    Write-Info "Baixando e instalando o Office via ODT (pode demorar alguns minutos, depende da internet)..."
    $proc = Start-Process -FilePath $odtExe -ArgumentList "/configure `"$configPath`"" -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        Write-Aviso "ODT terminou com código $($proc.ExitCode); confira o log do Office em %TEMP%."
        return
    }

    Write-Sucesso "Microsoft 365 Apps instalado. Abra qualquer app do Office e faça login com sua conta Microsoft 365 para ativar."
}

Register-Modulo -Id "office" -Titulo "Instalar Microsoft 365 Apps" `
    -Descricao "Word/Excel/PowerPoint/Outlook via Office Deployment Tool, no lugar do LibreOffice/OnlyOffice" `
    -Funcao ${function:Install-MicrosoftOffice}
