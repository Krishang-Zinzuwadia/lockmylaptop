$commandSvc = 'LockMyLaptop.CommandService'
$agentSvc = 'LockMyLaptop.LaptopAgent'

sc.exe stop $agentSvc | Out-Null
sc.exe stop $commandSvc | Out-Null

sc.exe delete $agentSvc
sc.exe delete $commandSvc
