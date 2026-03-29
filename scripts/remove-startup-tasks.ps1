$commandTask = 'LockMyLaptop.CommandService.Startup'
$agentTask = 'LockMyLaptop.LaptopAgent.Startup'

Unregister-ScheduledTask -TaskName $commandTask -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $agentTask -Confirm:$false -ErrorAction SilentlyContinue

Write-Host 'Startup tasks removed (if they existed).'
