$commandSvc = 'LockMyLaptop.CommandService'
$agentSvc = 'LockMyLaptop.LaptopAgent'

sc.exe start $commandSvc
sc.exe start $agentSvc
