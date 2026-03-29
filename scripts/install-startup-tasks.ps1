$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$commandExe = Join-Path $root '.deploy\command_service\LockMyLaptop.CommandService.exe'
$agentExe = Join-Path $root '.deploy\laptop_agent\LockMyLaptop.LaptopAgent.exe'
$commandLauncher = Join-Path $root 'scripts\start-command-service-hidden.ps1'
$agentLauncher = Join-Path $root 'scripts\start-laptop-agent-hidden.ps1'
$powershellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path $commandExe) -or -not (Test-Path $agentExe)) {
    throw 'Publish artifacts missing. Run scripts\publish.ps1 first.'
}

if (-not (Test-Path $commandLauncher) -or -not (Test-Path $agentLauncher)) {
    throw 'Hidden launcher scripts missing. Ensure scripts directory is up to date.'
}

$commandTask = 'LockMyLaptop.CommandService.Startup'
$agentTask = 'LockMyLaptop.LaptopAgent.Startup'

$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$principal = New-ScheduledTaskPrincipal -UserId $userId -RunLevel Limited -LogonType Interactive

$commandArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $commandLauncher
$agentArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $agentLauncher

$commandAction = New-ScheduledTaskAction -Execute $powershellExe -Argument $commandArgs
$agentAction = New-ScheduledTaskAction -Execute $powershellExe -Argument $agentArgs

Unregister-ScheduledTask -TaskName $commandTask -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $agentTask -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask -TaskName $commandTask -Action $commandAction -Trigger $trigger -Principal $principal | Out-Null
Register-ScheduledTask -TaskName $agentTask -Action $agentAction -Trigger $trigger -Principal $principal | Out-Null

Write-Host 'Startup tasks installed for current user.'
Write-Host 'Tasks:'
Write-Host "- $commandTask"
Write-Host "- $agentTask"
