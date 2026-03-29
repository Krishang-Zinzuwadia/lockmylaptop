$commandSvc = 'LockMyLaptop.CommandService'
$agentSvc = 'LockMyLaptop.LaptopAgent'

sc.exe stop $agentSvc
sc.exe stop $commandSvc
