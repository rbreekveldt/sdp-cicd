#!/bin/bash

. /home/oracle/.bashrc

<<EOF
CREATE TABLESPACE "sdp_db" DATAFILE '/oracle/app/oradata/orcl/sdp_db01.DBF' SIZE 5242880 AUTOEXTEND ON NEXT 1310720 MAXSIZE 32767M LOGGING ONLINE PERMANENT BLOCKSIZE 8192 EXTENT  MANAGEMENT LOCAL AUTOALLOCATE DEFAULT NOCOMPRESS  SEGMENT SPACE MANAGEMENT AUTO;

CREATE USER sdp_user IDENTIFIED BY "sdppwd" DEFAULT TABLESPACE "sdp_db" TEMPORARY TABLESPACE TEMP QUOTA UNLIMITED ON "sdp_db";

GRANT CONNECT, RESOURUCE TO sdp_user;

"jdbc:oracle:thin:@vm-x-sit-oracle01.internal.cloudapp.net:1521/ORCL", "sdp_user", "sdppwd"
EOF