#!/bin/bash

. /home/oracle/.bashrc

sqlplus / as oracle << EOF
CREATE OR REPLACE TRIGGER  startup_pluggable_dbs
AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE 'alter pluggable database all open';
END;
/
EOF
