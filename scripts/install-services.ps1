$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw 'Unable to auto-elevate: script path unavailable. Run this script in an Administrator PowerShell window.'
    }

    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $scriptPath
    ) -Wait
    exit $LASTEXITCODE
}

$root = Split-Path -Parent $PSScriptRoot
$commandExe = Join-Path $root '.deploy\command_service\LockMyLaptop.CommandService.exe'
$agentExe = Join-Path $root '.deploy\laptop_agent\LockMyLaptop.LaptopAgent.exe'

if (-not (Test-Path $commandExe) -or -not (Test-Path $agentExe)) {
    throw 'Publish artifacts missing. Run scripts\publish.ps1 first.'
}

$commandSvc = 'LockMyLaptop.CommandService'
$agentSvc = 'LockMyLaptop.LaptopAgent'

$commandBinPath = '"' + $commandExe + '" --urls "http://0.0.0.0:5000"'
$agentBinPath = '"' + $agentExe + '"'

sc.exe stop $commandSvc | Out-Null
sc.exe stop $agentSvc | Out-Null

sc.exe delete $commandSvc | Out-Null
sc.exe delete $agentSvc | Out-Null
Start-Sleep -Seconds 1

sc.exe create $commandSvc binPath= $commandBinPath start= auto | Out-Null
sc.exe create $agentSvc binPath= $agentBinPath start= auto | Out-Null

sc.exe start $commandSvc | Out-Null
sc.exe start $agentSvc | Out-Null

Write-Host 'Services installed and started.'
Write-Host 'Command service URL: http://<your-laptop-ip>:5000'
Write-Host 'Tip: set this URL in mobile app Settings once, then pairing persists across app restarts.'
