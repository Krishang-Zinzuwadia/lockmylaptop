param(
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host $Message
    }
}

$commandServiceName = 'LockMyLaptop.CommandService'
$agentServiceName = 'LockMyLaptop.LaptopAgent'

$commandService = Get-Service -Name $commandServiceName -ErrorAction SilentlyContinue
$agentService = Get-Service -Name $agentServiceName -ErrorAction SilentlyContinue

if ($null -ne $commandService -and $commandService.Status -eq 'Running') {
    Stop-Service -Name $commandServiceName -Force -ErrorAction SilentlyContinue
}

if ($null -ne $agentService -and $agentService.Status -eq 'Running') {
    Stop-Service -Name $agentServiceName -Force -ErrorAction SilentlyContinue
}

Stop-ScheduledTask -TaskName 'LockMyLaptop.CommandService.Startup' -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskName 'LockMyLaptop.LaptopAgent.Startup' -ErrorAction SilentlyContinue

Get-Process -Name 'LockMyLaptop.CommandService' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'LockMyLaptop.LaptopAgent' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Log 'Stopped LockMyLaptop background runtime.'
