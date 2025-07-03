# ========================================
# monitoring.ps1 - Script di monitoraggio
# ========================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\inetpub\wwwroot\$AppName\logs",
    
    [Parameter(Mandatory=$false)]
    [int]$IntervalSeconds = 60
)

Write-Host "👀 Avvio monitoraggio per $AppName" -ForegroundColor Green

function Get-ApplicationHealth {
    param([string]$AppName)
    
    $health = @{
        AppPool = "Unknown"
        Service = "Unknown"
        DiskSpace = 0
        Memory = 0
        CPU = 0
        LastError = $null
    }
    
    # Controlla Application Pool
    $appPoolName = "$($AppName)AppPool"
    $appPool = Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue
    if ($appPool) {
        $health.AppPool = $appPool.State
    }
    
    # Controlla spazio disco
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $health.DiskSpace = [math]::Round((($drive.Size - $drive.FreeSpace) / $drive.Size) * 100, 2)
    
    # Controlla memoria
    $memory = Get-WmiObject -Class Win32_OperatingSystem
    $health.Memory = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
    
    # Controlla CPU
    $cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $health.CPU = [math]::Round($cpu.Average, 2)
    
    # Controlla ultimi errori nei log
    if (Test-Path $LogPath) {
        $errorLogs = Get-ChildItem -Path $LogPath -Filter "*.log" | 
            Get-Content | 
            Where-Object { $_ -match "ERROR|FATAL" } | 
            Select-Object -Last 1
        
        if ($errorLogs) {
            $health.LastError = $errorLogs
        }
    }
    
    return $health
}

# Loop di monitoraggio
while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $health = Get-ApplicationHealth -AppName $AppName
    
    Write-Host "[$timestamp] Status Check:" -ForegroundColor Cyan
    Write-Host "  AppPool: $($health.AppPool)" -ForegroundColor $(if($health.AppPool -eq "Started") { "Green" } else { "Red" })
    Write-Host "  Disk Usage: $($health.DiskSpace)%" -ForegroundColor $(if($health.DiskSpace -lt 80) { "Green" } else { "Red" })
    Write-Host "  Memory Usage: $($health.Memory)%" -ForegroundColor $(if($health.Memory -lt 80) { "Green" } else { "Red" })
    Write-Host "  CPU Usage: $($health.CPU)%" -ForegroundColor $(if($health.CPU -lt 80) { "Green" } else { "Red" })
    
    if ($health.LastError) {
        Write-Host "  Last Error: $($health.LastError)" -ForegroundColor Red
    }
    
    # Allarmi
    if ($health.AppPool -ne "Started") {
        Write-Host "🚨 ALLARME: Application Pool non attivo!" -ForegroundColor Red
    }
    
    if ($health.DiskSpace -gt 90) {
        Write-Host "🚨 ALLARME: Spazio disco quasi esaurito!" -ForegroundColor Red
    }
    
    if ($health.Memory -gt 90) {
        Write-Host "🚨 ALLARME: Memoria quasi esaurita!" -ForegroundColor Red
    }
    
    Write-Host "----------------------------------------"
    
    Start-Sleep -Seconds $IntervalSeconds
}