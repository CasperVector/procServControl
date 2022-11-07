program procServControl("P=P")

%% #include <stdio.h>
%% #include <stdlib.h>
%% #include <string.h>
#ifdef _WIN32
%% #include <windows.h>
%% #include <process.h>
#else
%% #include <unistd.h>
#endif /* ifdef _WIN32 */
option +r;

/* This defines the number of lines and max line length */
#define LINELENGTH 256
#define NLINES 20

/* This is LINELENGTH*NLINES. It must match NELM on the IOCOUT and
 * PROCOUT waveform records */
#define NELM 5120

/* Inputs */
string port;            assign port            to "{P}:PORT";
int showout;            assign showout        to "{P}:SHOWOUT.VAL"; monitor showout;

/* Outputs */
string iocname;            assign iocname        to "{P}:IOCNAME";
int autorestart;        assign autorestart    to "{P}:AUTORESTART";
int status;                assign status        to "{P}:STATUS";
#define RUNNING 0
#define SHUTDOWN 1
#define PROCSERVSTOPPED 2
#define INVALIDPORTNAME 3
char iocout[NELM];        assign iocout        to "{P}:IOCOUT";

/* Commands */
int start;                assign start         to "{P}:START";
int stop;                assign stop         to "{P}:STOP";
int restart;            assign restart         to "{P}:RESTART";
int toggle;                assign toggle         to "{P}:TOGGLE";

/* Flags */
monitor start;            evflag startMon;    sync start startMon;
monitor stop;            evflag stopMon;        sync stop stopMon;
monitor restart;        evflag restartMon;    sync restart restartMon;
monitor toggle;            evflag toggleMon;    sync toggle toggleMon;
monitor status;            evflag statusMon;    sync status statusMon;

/* Internal variables for storing output lines*/
char iocLine[NLINES][LINELENGTH];
int iocLineI;
int lastcommand;
#define NONE 0
#define IOCOUT 1
#define AUTORESTART 2
#define IOCNAME 3
#define STATUS 4

/* These are needed to tie up the ppasynUser with the state machine */
int stateIndex;

/* we define two ports per ioc in build_ioc_startup, between ports 20000 and 49152
 * (port 49152 is start of IANA dynamic range for port allocation)
 * Therefore we can have at most ((49152 - 20000)/2) (=14576) iocs assuming all ports are free
 * Set max state machines at 10,000 to leave some room for ports which are in use.
 */
#define NSTATEMACHINES 10000
%% static int stateIndexGlobal = 0;

/* C functions and asyn things */
%% #include <asynOctetSyncIO.h>
%% static asynUser* pasynUsers[NSTATEMACHINES];
%% static void createAsynUser(struct UserVar *pVar);
%% static void getNextLine(struct UserVar *pVar);
%% static void writeControlChar(struct UserVar *pVar, const char *controlChar);

ss ssUserInput {
    state INIT {
        entry {
        }

        when() {
            /* Clear all event flags */
            efClear(startMon);
            efClear(stopMon);
            efClear(restartMon);
            efClear(toggleMon);
            efClear(statusMon);
        } state MONITORINPUTS
    }

    state MONITORINPUTS {

        entry {
        }

        when(efTestAndClear(startMon) && (start == 1)) {
            /* If we are shutdown then send CTRL-X to start */
            if (status == SHUTDOWN) {
                %% writeControlChar(pVar, "\x18");
            }
            start = 0;
            pvPut(start); /* not using SYNC as Busy record */
            efSet(statusMon); /* to avoid timeout if start when running */
        } state WAITFORRUNNING

        when(efTestAndClear(stopMon) && (stop == 1)) {
            /* If we are running, then make sure autorestart is off, if it isn't
             * send CTRL-T, then send CTRL-X to stop */
            if (status == RUNNING) {
                if (autorestart == 1) {
                    %% writeControlChar(pVar, "\x14");
                    autorestart = 0;
                    pvPut(autorestart, SYNC);
                }
                %% writeControlChar(pVar, "\x18");
            }
            stop = 0;
            pvPut(stop);  /* not using SYNC as Busy record */
            efSet(statusMon); /* to avoid timeout if stop when stopped */
        } state WAITFORSHUTDOWN

        when(efTestAndClear(restartMon) && (restart == 1)) {
            /* If we are running, then make sure autorestart is on, if it isn't
             * send CTRL-T, then send CTRL-X to restart */
            if (status == RUNNING) {
                if (autorestart == 0) {
                    %% writeControlChar(pVar, "\x14");
                    autorestart = 1;
                    pvPut(autorestart, SYNC);
                }
                %% writeControlChar(pVar, "\x18");
            }
            restart = 0;
            pvPut(restart);  /* not using SYNC as Busy record */
            efSet(statusMon); /* to avoid potential timeout error */
        } state WAITFORRESTART

        when(efTestAndClear(toggleMon) && (toggle == 1)) {
            /* If we are running, then send CTRL-T to toggle autorestart */
            if (status == RUNNING) {
                %% writeControlChar(pVar, "\x14");
            }
            toggle = 0;
            pvPut(toggle);  /* not using SYNC as Busy record */
        } state MONITORINPUTS
    }
    
    state WAITFORSHUTDOWN {
        entry {
        }
        
        when(efTestAndClear(statusMon) && (status == SHUTDOWN)) {
        } state MONITORINPUTS

        when(delay(5.0)) {
            printf("Timeout waiting for SHUTDOWN of %s\n", macValueGet("P"));
        } state MONITORINPUTS
    }

    state WAITFORRESTART {
        entry {
        }
        
        when(efTestAndClear(statusMon) && (status == SHUTDOWN)) {
        } state WAITFORRUNNING

        when(delay(5.0)) {
            printf("Timeout waiting for RESTART of %s\n", macValueGet("P"));
        } state MONITORINPUTS
    }

    state WAITFORRUNNING {
        entry {
        }
        
        when(efTestAndClear(statusMon) && (status == RUNNING)) {
        } state MONITORINPUTS

        /* need a long timeout here as tests with sending lots of consecutive
           commands seemed to require this */
        when(delay(30.0)) {
            printf("Timeout waiting for RUNNING of %s\n", macValueGet("P"));
        } state MONITORINPUTS
    }
}

ss ssProcServInput {
    state INIT {
        entry {
        }

        when() {
            /* Get the asyn port name */
            pvGet(port, SYNC);
            /* Connect the asyn port */
            %% createAsynUser(pVar);
        } state MONITORINPUTS
    }

    state MONITORINPUTS {

        entry {
        }

        when() {
            /* This sets lastcommand state */
            %% getNextLine(pVar);
        } state PROCESSINPUT
    }

    state PROCESSINPUT {
        entry {
        }

        when(lastcommand == NONE) {
        } state MONITORINPUTS

        when(lastcommand == IOCOUT) {
            pvPut(iocout, SYNC);
        } state MONITORINPUTS

        when(lastcommand == AUTORESTART) {
            pvPut(autorestart, SYNC);
            pvPut(iocout, SYNC);
        } state MONITORINPUTS

        when(lastcommand == IOCNAME) {
            pvPut(iocname, SYNC);
            pvPut(iocout, SYNC);
        } state MONITORINPUTS

        when(lastcommand == STATUS) {
            pvPut(status, SYNC);
            pvPut(iocout, SYNC);
        } state MONITORINPUTS
    }
}

/* C functions */
%{

static void do_sleep(float secs)
{
#ifdef _WIN32
    Sleep((int)(1000 * secs));
#else
    sleep(secs);
#endif /* ifdef _WIN32 */
}

/* Create an asynUser and set it up using the port name */
static void createAsynUser(struct UserVar *pVar) {
    int i;
    asynUser *pasynUser = NULL;
    /* Increment the global state machine counter */
    pVar->stateIndex = stateIndexGlobal++;
    if (stateIndexGlobal > NSTATEMACHINES) {
        printf("***Error: too many procServ state machines defined\n");
        return;
    }
    /* Connect the port */
    if (pasynOctetSyncIO->connect(pVar->port, 0, &pasynUser, NULL)) {
        /* Invalid port name, can't recover from this */
        printf("***Error: can't connect to asyn port name %s\n", pVar->port);
        pasynUser = NULL;
    } else {
        pasynOctetSyncIO->setInputEos(pasynUser, "\r\n", 2);
        pasynOctetSyncIO->setOutputEos(pasynUser, "", 0);
        pasynUsers[pVar->stateIndex] = pasynUser;
        /* Clear output lines */
        for (i = 0; i < NLINES; i++) {
            strcpy(pVar->iocLine[i], "");
        }
        pVar->iocLineI = 0;
    }
}

/* Get the next line of IOC output and process it */
static void getNextLine(struct UserVar *pVar) {
    char buffer[LINELENGTH];
    char temp[LINELENGTH];
    size_t bytes = 0;
    int eomReason;
    int i, index, yesNo;
    asynUser *pasynUser;

    /* By default there is nothing to do on return */
    pVar->lastcommand = NONE;

    /* Check that asynUser exists */
    if (pVar->stateIndex >= NSTATEMACHINES) return;
    pasynUser = pasynUsers[pVar->stateIndex];
    if (pasynUser == NULL) {
        if (pVar->status == INVALIDPORTNAME) {
            /* we can never recover, but at least we won't use all the CPU... */
            do_sleep(1);
        } else {
            pVar->lastcommand = STATUS;
            pVar->status = INVALIDPORTNAME;
        }
        return;
    }
    
    /* Check asynUser is connected */
    pasynManager->isConnected(pasynUser, &yesNo);
    
    if (yesNo == 0) {
        if (pVar->status == PROCSERVSTOPPED) {
            do_sleep(1);
        } else {
            pVar->status = PROCSERVSTOPPED;
            pVar->lastcommand = STATUS;
        }
        return;
    } else if (pVar->status == PROCSERVSTOPPED) {
        /* need to set the right eos if the port has just connected */
        pasynOctetSyncIO->setInputEos(pasynUser, "\r\n", 2);
        pasynOctetSyncIO->setOutputEos(pasynUser, "", 0);
        /* Note we don't set lastcommand as the status is just being used as
         * a flag so we don't set Eos many times. If it has just connected
         * procServ will tell us the status in 4 lines time anyway... */
        pVar->status = SHUTDOWN;
    }

    /* zero buffer, guarantees termination if we only read LINELENGTH-1 chars */
    memset(buffer, 0, LINELENGTH);

    /* read from the asyn port, if we fail (no data) just return */
    if ( pasynOctetSyncIO->read(pasynUser, buffer, LINELENGTH-1, 0.1, &bytes, &eomReason) || (bytes == 0) ) {
        do_sleep(0.1f);
        return;
    }

    /* put buffer in the right place */
    strcpy(pVar->iocLine[pVar->iocLineI], buffer);
    pVar->iocLineI = (pVar->iocLineI + 1) % NLINES;

    /* If we are told to show the result, copy the lines in the right order to
     * iocout */
    if (pVar->showout) {
        bytes = 0;
        /* Start with the line after the one just written (the oldest line) */
        for (i = 0; i < NLINES; i++) {
            index = (pVar->iocLineI + i)%NLINES;
            strcpy(pVar->iocout + bytes, pVar->iocLine[index]);
            bytes += strlen(pVar->iocLine[index]);
            /* Join with a \n */
            sprintf(pVar->iocout + bytes++, "\n");
        }
        /* zero out rest of array so we do not get any leftovers displayed */
        if ( bytes < sizeof(pVar->iocout) ) {
              memset(pVar->iocout + bytes, 0, sizeof(pVar->iocout) - bytes);
        }
        pVar->lastcommand = IOCOUT;
    }

    /* If it was a procServ command, parse it */
    if (buffer[0] == '@' && buffer[1] == '@' && buffer[2] == '@') {
        /*printf("%s: {%s}\n", pVar->port, buffer);*/
        /* grab ioc name */
        if (sscanf(buffer, "@@@ Child \"%s started as: %s", pVar->iocname, temp) == 2) {
            pVar->iocname[strlen(pVar->iocname)-1] = '\0';
            pVar->lastcommand = IOCNAME;
            /*printf("iocname: %s\n", pVar->iocname);*/
            return;
        }
        /* grab current status */
        if (sscanf(buffer, "@@@ Child \"%*s %s", temp)) {
            if (strcmp(temp, "PID:") == 0) {
                pVar->status = RUNNING;
            } else if (strcmp(temp, "is") == 0) {
                pVar->status = SHUTDOWN;
            } else {
                /*printf("status (invalid): %s\n", temp);*/
                return;
            }
            /*printf("status (1): (%s) %d\n", temp, pVar->status);*/
            pVar->lastcommand = STATUS;
            return;
        }
        if (sscanf(buffer, "@@@ Restarting child %s", temp)) {
            pVar->lastcommand = STATUS;
               pVar->status = RUNNING;
            /*printf("status (2): %d\n", pVar->status);*/
            return;
        }
        if (sscanf(buffer, "@@@ Child process is shutting %s", temp)) {
            pVar->lastcommand = STATUS;
               pVar->status = SHUTDOWN;
            /*printf("status (3): %d\n", pVar->status);*/
            return;
        }
        /* grab current autorestart */
        if (sscanf(buffer, "@@@ Toggled auto restart to %s", temp)) {
            pVar->lastcommand = AUTORESTART;
            if (strcmp(temp, "ON") == 0) {
                pVar->autorestart = 1;
            } else {
                pVar->autorestart = 0;
            }
            /*printf("autorestart (1): %d\n", pVar->autorestart);*/
            return;
        }
        if (sscanf(buffer, "@@@ Use ^X to kill the child, auto restart is %s", temp)) {
            pVar->lastcommand = AUTORESTART;
            if (strcmp(temp, "ON,") == 0) {
                pVar->autorestart = 1;
            } else {
                pVar->autorestart = 0;
            }
            /*printf("autorestart (2): %d\n", pVar->autorestart);*/
            return;
        }
    }
}

/* Write a control char to procServ */
static void writeControlChar(struct UserVar *pVar, const char *controlChar) {
    size_t bytes;
    int yesNo;
    asynUser *pasynUser;

    /* Check that asynUser exists */
    if (pVar->stateIndex >= NSTATEMACHINES) return;
    pasynUser = pasynUsers[pVar->stateIndex];
    if (pasynUser == NULL) return;

    /* Check asynUser is connected */
    pasynManager->isConnected(pasynUser, &yesNo);
    if (yesNo == 0) return;

    /* Write control char to procServ */
    pasynOctetSyncIO->write(pasynUser, controlChar, 1, 1.0, &bytes);
}

}%


