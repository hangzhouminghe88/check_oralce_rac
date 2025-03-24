#!/bin/bash

# Oracle RAC Health Check Script
# Author:  Zhi Gang Liang
#  2025 03 24
# Usage: run as 'grid' user

# === Configuration ===
DB_NAME="kqfbhis"
LOGFILE="/tmp/rac_health_$(date +%F_%H-%M-%S).log"
GRID_ALERT_LOG="/u01/app/grid/11204/log/diag/asmcmd/user_grid/$(hostname)/alert/alert.log"

echo "========= Oracle RAC Health Check ($(date)) =========" | tee -a $LOGFILE

# 1. CRS resource status
echo -e "\n-- 1. CRS Resource Status --" | tee -a $LOGFILE
crsctl stat res -t | tee -a $LOGFILE

# 2. Cluster node status
echo -e "\n-- 2. Cluster Node Status --" | tee -a $LOGFILE
olsnodes -n -s | tee -a $LOGFILE

# 3. Database instance status
echo -e "\n-- 3. Database Instance Status (srvctl) --" | tee -a $LOGFILE
srvctl status database -d $DB_NAME | tee -a $LOGFILE

# 4. GV$INSTANCE (requires oracle user or proper environment)
echo -e "\n-- 4. Database Instance Status (GV\$INSTANCE) --" | tee -a $LOGFILE
sqlplus -S / as sysdba <<EOF >> $LOGFILE
SET LINESIZE 200
COL INSTANCE_NAME FOR A15
COL HOST_NAME FOR A20
COL STATUS FOR A10
SELECT INSTANCE_NAME, HOST_NAME, STATUS FROM GV\$INSTANCE;
EXIT;
EOF

# 5. ASM Diskgroup usage
echo -e "\n-- 5. ASM Diskgroup Usage --" | tee -a $LOGFILE
sqlplus -S / as sysasm <<EOF >> $LOGFILE
SET LINESIZE 150
COL NAME FOR A20
SELECT NAME, TOTAL_MB, FREE_MB, ROUND((FREE_MB/TOTAL_MB)*100,2) AS FREE_PCT
FROM V\$ASM_DISKGROUP;
EXIT;
EOF

# 6. Listener status
echo -e "\n-- 6. Listener Status --" | tee -a $LOGFILE
lsnrctl status | tee -a $LOGFILE

# 7. VIP & SCAN status (explicit resource names)
echo -e "\n-- 7. VIP and SCAN Status --" | tee -a $LOGFILE
crsctl stat res ora.rac1.vip -t | tee -a $LOGFILE
crsctl stat res ora.rac2.vip -t | tee -a $LOGFILE
crsctl stat res ora.scan1.vip -t | tee -a $LOGFILE

# 8. Alert log check (last 100 lines with keywords)
echo -e "\n-- 8. Cluster Alert Log Warnings (Last 100 Lines) --" | tee -a $LOGFILE
if [[ -f "$GRID_ALERT_LOG" ]]; then
    tail -n 100 "$GRID_ALERT_LOG" | grep -iE "error|warning|fail" | tee -a $LOGFILE
else
    echo "Alert log not found at $GRID_ALERT_LOG" | tee -a $LOGFILE
fi

echo -e "\n========= Health Check Completed ? Log saved at: $LOGFILE =========" | tee -a $LOGFILE
