$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$commandExe = Join-Path $root '.deploy\command_service\LockMyLaptop.CommandService.exe'
$commandDir = Split-Path -Parent $commandExe

if (-not (Test-Path $commandExe)) {
    throw 'Command service artifact missing. Run scripts\publish.ps1 first.'
}

$running = Get-Process -Name 'LockMyLaptop.CommandService' -ErrorAction SilentlyContinue
if ($null -eq $running) {
    Start-Process -FilePath $commandExe -ArgumentList @('--urls', 'http://0.0.0.0:5000') -WorkingDirectory $commandDir -WindowStyle Hidden | Out-Null
}
