# ========================================
# rollback.ps1 - Script di rollback
# ========================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentPath = "C:\inetpub\wwwroot\$AppName",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupPath
)

Write-Host "🔄 Avvio rollback per $AppName" -ForegroundColor Yellow

# Se non è specificato un backup, usa il più recente
if (-not $BackupPath) {
    $backupDir = Split-Path $DeploymentPath -Parent
    $latestBackup = Get-ChildItem -Path $backupDir -Directory | 
        Where-Object { $_.Name -like "*_backup_*" } | 
        Sort-Object CreationTime -Descending | 
        Select-Object -First 1
    
    if ($latestBackup) {
        $BackupPath = $latestBackup.FullName
        Write-Host "📁 Backup più recente trovato: $BackupPath" -ForegroundColor Green
    } else {
        Write-Error "❌ Nessun backup trovato per il rollback"
        exit 1
    }
}

# Verifica esistenza backup
if (-not (Test-Path $BackupPath)) {
    Write-Error "❌ Backup non trovato: $BackupPath"
    exit 1
}

# Stop servizi
Write-Host "⏹️ Stop servizi..." -ForegroundColor Yellow
$appPoolName = "$($AppName)AppPool"
if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
    Stop-WebAppPool -Name $appPoolName
}

# Backup dell'applicazione corrente (per sicurezza)
$currentBackup = "$DeploymentPath" + "_rollback_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Write-Host "💾 Backup dell'applicazione corrente: $currentBackup" -ForegroundColor Yellow
Copy-Item -Path $DeploymentPath -Destination $currentBackup -Recurse -Force

# Rimozione applicazione corrente
Write-Host "🗑️ Rimozione applicazione corrente..." -ForegroundColor Yellow
Remove-Item -Path "$DeploymentPath\*" -Recurse -Force

# Ripristino dal backup
Write-Host "📥 Ripristino dal backup..." -ForegroundColor Yellow
Copy-Item -Path "$BackupPath\*" -Destination $DeploymentPath -Recurse -Force

# Restart servizi
Write-Host "▶️ Restart servizi..." -ForegroundColor Yellow
if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
    Start-WebAppPool -Name $appPoolName
}

# Health check
Write-Host "🏥 Health check..." -ForegroundColor Yellow
$healthCheckUrl = "http://localhost/health"
$maxRetries = 5
$retryDelay = 10

for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        $response = Invoke-RestMethod -Uri $healthCheckUrl -Method GET -TimeoutSec 30
        if ($response.Status -eq "Healthy") {
            Write-Host "✅ Rollback completato con successo!" -ForegroundColor Green
            exit 0
        }
    } catch {
        Write-Warning "❌ Health check failed on attempt $i"
    }
    
    if ($i -lt $maxRetries) {
        Start-Sleep -Seconds $retryDelay
    }
}

Write-Error "❌ Rollback completato ma health check fallito"
exit 1