$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$commandExe = Join-Path $root '.deploy\command_service\LockMyLaptop.CommandService.exe'
$agentExe = Join-Path $root '.deploy\laptop_agent\LockMyLaptop.LaptopAgent.exe'

if (-not (Test-Path $commandExe) -or -not (Test-Path $agentExe)) {
    throw 'Publish artifacts missing. Run scripts\publish.ps1 first.'
}

$commandTask = 'LockMyLaptop.CommandService.Startup'
$agentTask = 'LockMyLaptop.LaptopAgent.Startup'

$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$principal = New-ScheduledTaskPrincipal -UserId $userId -RunLevel Limited -LogonType Interactive

$commandAction = New-ScheduledTaskAction -Execute $commandExe -Argument '--urls http://0.0.0.0:5000'
$agentAction = New-ScheduledTaskAction -Execute $agentExe

Unregister-ScheduledTask -TaskName $commandTask -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $agentTask -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask -TaskName $commandTask -Action $commandAction -Trigger $trigger -Principal $principal | Out-Null
Register-ScheduledTask -TaskName $agentTask -Action $agentAction -Trigger $trigger -Principal $principal | Out-Null

Write-Host 'Startup tasks installed for current user.'
Write-Host 'Tasks:'
Write-Host "- $commandTask"
Write-Host "- $agentTask"
