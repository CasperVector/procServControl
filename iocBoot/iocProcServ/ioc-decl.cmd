drvAsynIPPortConfigure("${PORT}", "${DEVICE}")
dbLoadRecords("${TOP}/db/procServControl.template", "P=${P},PORT=${PORT}")

