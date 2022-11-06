TOP = ../..
include $(TOP)/configure/CONFIG

PROD_IOC = example
DBD += example.dbd
example_DBD += base.dbd
example_DBD += asyn.dbd
example_DBD += drvAsynIPPort.dbd
example_DBD += busySupport.dbd
example_DBD += procServControl.dbd
example_SRCS += example_registerRecordDeviceDriver.cpp
example_LIBS += procServControl
example_LIBS += busy
example_LIBS += seq
example_LIBS += pv
example_LIBS += asyn
example_LIBS += $(EPICS_BASE_IOC_LIBS)
example_SRCS += exampleMain.cpp

include $(TOP)/configure/RULES

