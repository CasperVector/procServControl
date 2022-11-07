#!../../bin/linux-x86_64/procServControlApp

< envPaths
cd "${TOP}"
dbLoadDatabase "dbd/procServControlApp.dbd"
procServControlApp_registerRecordDeviceDriver(pdbbase)

cd "${TOP}/iocBoot/${IOC}"
iocshLoad("ioc-decl.cmd", "PORT=port1,P=ProcServ:IOC01:,DEVICE=localhost:7001")
iocshLoad("ioc-decl.cmd", "PORT=port2,P=ProcServ:IOC02:,DEVICE=localhost:7002")

iocInit()
seq(procServControl, "P=ProcServ:IOC01:")
seq(procServControl, "P=ProcServ:IOC02:")

