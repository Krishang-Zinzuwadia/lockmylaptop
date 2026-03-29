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

$root = Split-Path -Parent $PSScriptRoot
$commandExe = Join-Path $root '.deploy\command_service\LockMyLaptop.CommandService.exe'
$agentExe = Join-Path $root '.deploy\laptop_agent\LockMyLaptop.LaptopAgent.exe'

if (-not (Test-Path $commandExe) -or -not (Test-Path $agentExe)) {
    throw 'Publish artifacts missing. Run scripts\publish.ps1 first.'
}

$commandServiceName = 'LockMyLaptop.CommandService'
$agentServiceName = 'LockMyLaptop.LaptopAgent'

$commandService = Get-Service -Name $commandServiceName -ErrorAction SilentlyContinue
$agentService = Get-Service -Name $agentServiceName -ErrorAction SilentlyContinue
if ($null -ne $commandService -or $null -ne $agentService) {
    if ($null -ne $commandService -and $commandService.Status -ne 'Running') {
        Start-Service -Name $commandServiceName -ErrorAction SilentlyContinue
    }

    if ($null -ne $agentService -and $agentService.Status -ne 'Running') {
        Start-Service -Name $agentServiceName -ErrorAction SilentlyContinue
    }

    Write-Log 'Started runtime via Windows services.'
    return
}

$commandTaskName = 'LockMyLaptop.CommandService.Startup'
$agentTaskName = 'LockMyLaptop.LaptopAgent.Startup'

$commandTask = Get-ScheduledTask -TaskName $commandTaskName -ErrorAction SilentlyContinue
$agentTask = Get-ScheduledTask -TaskName $agentTaskName -ErrorAction SilentlyContinue
if ($null -ne $commandTask -or $null -ne $agentTask) {
    if ($null -ne $commandTask) {
        Start-ScheduledTask -TaskName $commandTaskName -ErrorAction SilentlyContinue
    }

    if ($null -ne $agentTask) {
        Start-ScheduledTask -TaskName $agentTaskName -ErrorAction SilentlyContinue
    }

    Write-Log 'Started runtime via scheduled startup tasks.'
    return
}

$started = @()
$commandRunning = Get-Process -Name 'LockMyLaptop.CommandService' -ErrorAction SilentlyContinue
if ($null -eq $commandRunning) {
    $proc = Start-Process -FilePath $commandExe -ArgumentList @('--urls', 'http://0.0.0.0:5000') -WindowStyle Hidden -PassThru
    $started += "command service process PID $($proc.Id)"
}

$agentRunning = Get-Process -Name 'LockMyLaptop.LaptopAgent' -ErrorAction SilentlyContinue
if ($null -eq $agentRunning) {
    $proc = Start-Process -FilePath $agentExe -WindowStyle Hidden -PassThru
    $started += "laptop agent process PID $($proc.Id)"
}

if ($started.Count -eq 0) {
    Write-Log 'Runtime already running in background.'
}
else {
    Write-Log ('Started background runtime: ' + ($started -join ', '))
}
