# ========================================
# setup-vm.ps1 - Script di configurazione iniziale della VM
# ========================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentPath = "C:\inetpub\wwwroot\$AppName",
    
    [Parameter(Mandatory=$false)]
    [bool]$InstallIIS = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$InstallDotNet = $true
)

Write-Host "🚀 Configurazione VM per $AppName" -ForegroundColor Green

# Installazione delle feature Windows necessarie
if ($InstallIIS) {
    Write-Host "📦 Installazione IIS..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-DirectoryBrowsing -All
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All
    
    # Installa ASP.NET Core Module
    Write-Host "📦 Installazione ASP.NET Core Hosting Bundle..." -ForegroundColor Yellow
    $hostingBundleUrl = "https://download.visualstudio.microsoft.com/download/pr/2a7ae819-fbc4-4611-a1ba-f3b072d4ea25/32f3b8d7cbd9aa690cf26b203c3d4a6e/dotnet-hosting-9.0.0-win.exe"
    $tempFile = "$env:TEMP\dotnet-hosting-bundle.exe"
    
    Invoke-WebRequest -Uri $hostingBundleUrl -OutFile $tempFile
    Start-Process -FilePath $tempFile -ArgumentList "/quiet" -Wait
    Remove-Item $tempFile
    
    # Restart IIS
    Write-Host "🔄 Riavvio IIS..." -ForegroundColor Yellow
    iisreset
}

# Installazione .NET Runtime se necessario
if ($InstallDotNet) {
    Write-Host "📦 Installazione .NET 9.0 Runtime..." -ForegroundColor Yellow
    $dotnetUrl = "https://download.visualstudio.microsoft.com/download/pr/2a7ae819-fbc4-4611-a1ba-f3b072d4ea25/dotnet-runtime-9.0.0-win-x64.exe"
    $tempFile = "$env:TEMP\dotnet-runtime.exe"
    
    Invoke-WebRequest -Uri $dotnetUrl -OutFile $tempFile
    Start-Process -FilePath $tempFile -ArgumentList "/quiet" -Wait
    Remove-Item $tempFile
}

# Creazione delle directory necessarie
Write-Host "📁 Creazione directory di deployment..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $DeploymentPath -Force
New-Item -ItemType Directory -Path "$DeploymentPath\logs" -Force

# Configurazione permessi
Write-Host "🔒 Configurazione permessi..." -ForegroundColor Yellow
$acl = Get-Acl $DeploymentPath
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl -Path $DeploymentPath -AclObject $acl

# Configurazione Firewall
Write-Host "🔥 Configurazione Firewall..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "HTTP-In" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "HTTPS-In" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

Write-Host "✅ Configurazione VM completata!" -ForegroundColor Green