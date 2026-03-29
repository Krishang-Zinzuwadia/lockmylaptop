$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$agentExe = Join-Path $root '.deploy\laptop_agent\LockMyLaptop.LaptopAgent.exe'
$agentDir = Split-Path -Parent $agentExe

if (-not (Test-Path $agentExe)) {
    throw 'Laptop agent artifact missing. Run scripts\publish.ps1 first.'
}

$running = Get-Process -Name 'LockMyLaptop.LaptopAgent' -ErrorAction SilentlyContinue
if ($null -eq $running) {
    Start-Process -FilePath $agentExe -WorkingDirectory $agentDir -WindowStyle Hidden | Out-Null
}
