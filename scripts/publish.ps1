$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Step {
	param([string]$Name, [scriptblock]$Action)
	Write-Host $Name
	& $Action
	if ($LASTEXITCODE -ne 0) {
		throw "$Name failed with exit code $LASTEXITCODE"
	}
}

Write-Host 'Stopping running LockMyLaptop services/processes (if any)...'
sc.exe stop LockMyLaptop.CommandService | Out-Null
sc.exe stop LockMyLaptop.LaptopAgent | Out-Null

$running = Get-CimInstance Win32_Process | Where-Object {
	($_.Name -eq 'dotnet.exe' -and $_.CommandLine -match 'LockMyLaptop|lockmylaptop') -or
	($_.Name -in @('LockMyLaptop.CommandService.exe','LockMyLaptop.LaptopAgent.exe'))
}
foreach ($proc in $running) {
	try {
		Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
	} catch {
		# ignore
	}
}

Start-Sleep -Seconds 1

Invoke-Step 'Publishing command service...' { dotnet publish .\command_service\LockMyLaptop.CommandService.csproj -c Release -o .\.deploy\command_service }
Invoke-Step 'Publishing laptop agent...' { dotnet publish .\laptop_agent\LockMyLaptop.LaptopAgent.csproj -c Release -o .\.deploy\laptop_agent }

Write-Host 'Building Android release APK...'
$flutter = Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'
Set-Location .\mobile_android
Invoke-Step 'Resolving Flutter dependencies...' { & $flutter pub get }
Invoke-Step 'Building APK...' { & $flutter build apk --release }

Write-Host 'Publish complete.'
