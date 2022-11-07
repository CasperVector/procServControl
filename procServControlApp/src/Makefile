TOP=../..

include $(TOP)/configure/CONFIG

LIBRARY_IOC += procServControl
DBD += procServControl.dbd
procServControl_SRCS += procServControl.st
procServControl_LIBS += $(EPICS_BASE_IOC_LIBS)

PROD_IOC = procServControlApp
DBD += procServControlApp.dbd
procServControlApp_SRCS += procServControlApp_registerRecordDeviceDriver.cpp
procServControlApp_SRCS_DEFAULT += procServControlMain.cpp

procServControlApp_DBD += base.dbd asyn.dbd drvAsynIPPort.dbd
procServControlApp_DBD += busySupport.dbd procServControl.dbd
procServControlApp_LIBS += seq pv asyn busy procServControl
procServControlApp_LIBS += $(EPICS_BASE_IOC_LIBS)

include $(TOP)/configure/RULES

