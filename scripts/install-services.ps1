$ErrorActionPreference = 'Stop'

function Invoke-Sc {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & sc.exe @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if (-not $AllowFailure -and $exitCode -ne 0) {
        $joined = $Arguments -join ' '
        $message = ($output | Out-String).Trim()
        throw "sc.exe $joined failed with exit code $exitCode. $message"
    }

    return $output
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw 'Unable to auto-elevate: script path unavailable. Run this script in an Administrator PowerShell window.'
    }

    $elevated = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $scriptPath
    )
    $elevated.WaitForExit()
    if ($elevated.ExitCode -ne 0) {
        throw "Elevated install failed with exit code $($elevated.ExitCode)."
    }
    exit 0
}

$root = Split-Path -Parent $PSScriptRoot
$commandExe = Join-Path $root '.deploy\command_service\LockMyLaptop.CommandService.exe'
$agentExe = Join-Path $root '.deploy\laptop_agent\LockMyLaptop.LaptopAgent.exe'

if (-not (Test-Path $commandExe) -or -not (Test-Path $agentExe)) {
    throw 'Publish artifacts missing. Run scripts\publish.ps1 first.'
}

$commandSvc = 'LockMyLaptop.CommandService'
$agentSvc = 'LockMyLaptop.LaptopAgent'

$commandBinPath = '"' + $commandExe + '" --urls http://0.0.0.0:5000'
$agentBinPath = '"' + $agentExe + '"'

Invoke-Sc -Arguments @('stop', $commandSvc) -AllowFailure | Out-Null
Invoke-Sc -Arguments @('stop', $agentSvc) -AllowFailure | Out-Null

Invoke-Sc -Arguments @('delete', $commandSvc) -AllowFailure | Out-Null
Invoke-Sc -Arguments @('delete', $agentSvc) -AllowFailure | Out-Null
Start-Sleep -Seconds 1

Invoke-Sc -Arguments @('create', $commandSvc, 'binPath=', $commandBinPath, 'start=', 'auto') | Out-Null
Invoke-Sc -Arguments @('create', $agentSvc, 'binPath=', $agentBinPath, 'start=', 'auto') | Out-Null

Invoke-Sc -Arguments @('start', $commandSvc) | Out-Null
Invoke-Sc -Arguments @('start', $agentSvc) | Out-Null

Write-Host 'Services installed and started.'
Write-Host 'Command service URL: http://<your-laptop-ip>:5000'
Write-Host 'Tip: set this URL in mobile app Settings once, then pairing persists across app restarts.'
