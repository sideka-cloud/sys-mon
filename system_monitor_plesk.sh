#!/bin/bash

# Log directory
LOG_DIR="/var/log/system_monitor"
mkdir -p $LOG_DIR

# Monitoring interval in seconds
INTERVAL=60

# Infinite loop to monitor the system
while true; do
    # Get the current date for log file naming
    CURRENT_DATE=$(date "+%d%b" | tr '[:upper:]' '[:lower:]')
    OUTPUT_FILE="$LOG_DIR/sysmon_${CURRENT_DATE}.log"

    # Get the current timestamp
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Get CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    # Get Load Average (1m, 5m, 15m)
    LOAD_AVERAGE=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

    # Get RAM usage
    RAM_USAGE=$(free -m | awk '/Mem:/ {print $3}')

    # Get Swap usage
    SWAP_USAGE=$(free -m | awk '/Swap:/ {print $3}')

    # Get Disk Read/Write (KB/s)
    DISK_IO=$(iostat -d | awk '/[svx]da/ {print $3, $4}')

    # Get Network Up/Down (KB/s) using sar and sum all interfaces
    NETWORK_IO=$(sar -n DEV 1 1 | awk '/Average/ && ($2 != "lo" && $2 != "IFACE") {rx+=$5; tx+=$6} END {print tx, rx}')

    # Get top 15 processes by CPU usage and include the full command
    TOP_PROCESSES_CPU=$(top -c -b -n2 -w 200 -o %CPU | awk '
        BEGIN {
            # Print the header line
            printf "%-8s %-8s %-4s %-8s %-6s %-6s %-10s %s\n", "PID", "USER", "PR", "VIRT", "%CPU", "%MEM", "TIME+", "COMMAND";
        }
        NR>7 {
            # Skip summary lines (lines with fewer than 12 fields or non-numeric PID)
            if (NF >= 12 && $1 ~ /^[0-9]+$/) {
                # Extract relevant fields
                pid = $1;      # PID
                user = $2;     # USER
                pr = $3;       # PR
                virt = $5;     # VIRT
                cpu = $9;      # %CPU
                mem = $10;     # %MEM
                time = $11;    # TIME+
                cmd = substr($0, index($0, $12));  # COMMAND (from column 12 to end of line)
                # Print the formatted output
                printf "%-8s %-8s %-4s %-8s %-6s %-6s %-10s %s\n", pid, user, pr, virt, cpu, mem, time, cmd;
            }
        }
    ' | head -n 15)  # Limit to top 15 processes

    # Get top 15 processes by RAM usage and include the full command
    TOP_PROCESSES_RAM=$(top -c -b -n2 -w 200 -o %MEM | awk '
        BEGIN {
            # Print the header line
            printf "%-8s %-8s %-4s %-8s %-6s %-6s %-10s %s\n", "PID", "USER", "PR", "VIRT", "%CPU", "%MEM", "TIME+", "COMMAND";
        }
        NR>7 {
            # Skip summary lines (lines with fewer than 12 fields or non-numeric PID)
            if (NF >= 12 && $1 ~ /^[0-9]+$/) {
                # Extract relevant fields
                pid = $1;      # PID
                user = $2;     # USER
                pr = $3;       # PR
                virt = $5;     # VIRT
                cpu = $9;      # %CPU
                mem = $10;     # %MEM
                time = $11;    # TIME+
                cmd = substr($0, index($0, $12));  # COMMAND (from column 12 to end of line)
                # Print the formatted output
                printf "%-8s %-8s %-4s %-8s %-6s %-6s %-10s %s\n", pid, user, pr, virt, cpu, mem, time, cmd;
            }
        }
    ' | head -n 15)  # Limit to top 15 processes

    # Get top 15 cumulative RAM usage for all process
    TOP_RAM_1=$(ps -eo comm,rss | awk '{arr[$1]+=$2} END {for (i in arr) printf "%-20s %10.1f MB\n", i, arr[i]/1024}' | sort -k2 -nr | head -15)
    # Get top 10 php ram usage
    TOP_RAM_2=$(ps -eo pid,rss,comm | grep -E 'php|php-fpm|lsphp' | while read pid rss comm; do
    uid=$(awk '/Uid:/ {print $2}' /proc/$pid/status 2>/dev/null)
    user=$(getent passwd $uid | cut -d: -f1)
    cwd=$(ls -l /proc/$pid/cwd 2>/dev/null | awk '{print $NF}')
    rss_mb=$(echo "scale=1; $rss/1024" | bc)
    printf "%6s %-12s %-15s %8.1f MB %-40s\n" "$pid" "$comm" "$user" "$rss_mb" "$cwd"
    done | sort -k4 -nr | head -10)
    
    TOP_RAM_3=$(declare -A user_total
    while read pid rss comm; do
    uid=$(awk '/Uid:/ {print $2}' /proc/$pid/status 2>/dev/null)
    user=$(getent passwd $uid | cut -d: -f1)
    [[ -z "$user" ]] && continue
    user_total[$user]=$(( ${user_total[$user]:-0} + rss ))
    done < <(ps -eo pid,rss,comm | grep -E 'php|php-fpm|lsphp')

    for user in "${!user_total[@]}"; do
    rss_kb=${user_total[$user]}
    rss_mb=$(echo "scale=1; $rss_kb/1024" | bc)
    printf "%-15s %8.1f MB\n" "$user" "$rss_mb"
    done | sort -k2 -nr | head -10)

    # Save full status output for Apache
    STATUS_LOG="/var/log/system_monitor/apache_status.log"
    apachectl fullstatus > "$STATUS_LOG"

    # Extract main server status info for Apache
    APACHE_STATUS=$(awk '
        /Current Time:/ {print}
        /Restart Time:/ {print}
        /Parent Server Config. Generation:/ {print}
        /Parent Server MPM Generation:/ {print}
        /Server uptime:/ {print}
        /Server load:/ {print}
        /Total accesses:/ {print}
        /CPU Usage:/ {print}
        /^[[:space:]]*[0-9]+ requests currently being processed/ {print}
    ' "$STATUS_LOG")

    # Extract top IPs client for Apache
    TOP_IPS_CLIENT=$(awk '$0 ~ /^[0-9-]+\s+[0-9]+\s+[0-9\/]+\/[0-9\/]+\/[0-9\/]+\s+/ {print $12}' "$STATUS_LOG" | sort | uniq -c | sort -nr | head -20)

    # Extract top virtual hosts for Apache
    TOP_VIRTUAL_HOSTS=$(awk '$0 ~ /^[0-9-]+\s+[0-9]+\s+[0-9\/]+\/[0-9\/]+\/[0-9\/]+\s+/ {print $14}' "$STATUS_LOG" | sort | uniq -c | sort -nr | head -20)

    # Extract top requests for Apache
    TOP_REQUESTS=$(apachectl fullstatus | awk '$0 ~ /^[0-9-]+\s+[0-9]+\s+[0-9\/]+\/[0-9\/]+\/[0-9\/]+\s+/ {print $(NF-2), $(NF-1), $NF}' | sort | uniq -c | sort -nr | head -20)

    # Get MySQL connection status
    MYSQL_CONNECTION=$(echo "Current Connections: $(plesk db -Nse "SHOW STATUS WHERE Variable_name = 'Threads_connected'" | awk '{print $2}')")
    MYSQL_CONNECTION="$MYSQL_CONNECTION\nMax Used Connections: $(plesk db -Nse "SHOW STATUS WHERE Variable_name = 'Max_used_connections'" | awk '{print $2}')"
    MYSQL_CONNECTION="$MYSQL_CONNECTION\nMax Allowed Connections: $(plesk db -Nse "SHOW VARIABLES WHERE Variable_name = 'max_connections'" | awk '{print $2}')"

    # Get MySQL InnoDB status
    MYSQL_INNODB=$(echo "InnoDB Buffer Pool Size: $(plesk db -Nse "SHOW VARIABLES WHERE Variable_name = 'innodb_buffer_pool_size'" | awk '{printf "%.2f GB\n", $2 / (1024*1024*1024)}')")
    MYSQL_INNODB="$MYSQL_INNODB\nInnoDB Buffer Pool Usage: $(plesk db -Nse "SHOW STATUS WHERE Variable_name IN ('Innodb_buffer_pool_pages_total', 'Innodb_buffer_pool_pages_free')" | awk '{a[$1]=$2} END {printf "%.2f%%\n", 100*(1 - a["Innodb_buffer_pool_pages_free"] / a["Innodb_buffer_pool_pages_total"]) }')"

    # Get MySQL query status
    MYSQL_RUN=$(plesk db -Nse "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep';")
    MYSQL_SLEEP=$(plesk db -Nse "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND = 'Sleep' AND INFO IS NULL;")
    MYSQL_QUERY=$(plesk db -B -e "SELECT * FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep';" | head -n 30)

    # Get Apache and MySQL logs
    APACHE_LOGS=$(journalctl -u httpd --no-pager -n 10)
    MYSQL_LOGS=$(journalctl -u mariadb --no-pager -n 10)

    # Get I/O status
    TOP_PROCESSES_IO=$(iotop -b -n 3 -o -P -k | awk '!/Total DISK READ/ && !/Actual DISK READ/ && !seen[$0]++' | awk '{print substr($0, 1, 140)}' | head -n 20) 

    # Get OOM status
    OOM=$(grep "Out of memory" /var/log/messages | head -n10)
    
    # Get Total Email Queue
    QUEUE=$(postqueue -p | grep -c '^[A-F0-9]')
    TOP_QUEUE=$(postqueue -p | awk '/^[A-F0-9]/ {print $7}' | sort | uniq -c | sort -nr | head -5)
    
    # Append the data to the output file
    echo "Timestamp: $TIMESTAMP" >> $OUTPUT_FILE
    echo "CPU Usage (All Core): $CPU_USAGE%" >> $OUTPUT_FILE
    echo "Load Average (1m, 5m, 15m): $LOAD_AVERAGE" >> $OUTPUT_FILE
    echo "RAM Usage: $RAM_USAGE MB" >> $OUTPUT_FILE
    echo "Swap Usage: $SWAP_USAGE MB" >> $OUTPUT_FILE
    echo "Disk R/W: $DISK_IO KB/s" >> $OUTPUT_FILE
    echo "Network Up/Down: $NETWORK_IO KB/s" >> $OUTPUT_FILE
    echo "---------------------------------------" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 15 Processes by CPU Usage ====" >> $OUTPUT_FILE
    echo "$TOP_PROCESSES_CPU" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 15 Processes by RAM Usage ====" >> $OUTPUT_FILE
    echo "$TOP_PROCESSES_RAM" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 15 Cumulative RAM Usage ====" >> $OUTPUT_FILE
    echo "$TOP_RAM_1" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 10 RAM Usage by PHP ====" >> $OUTPUT_FILE
    echo "$TOP_RAM_2" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 10 RAM Usage by domain|user ====" >> $OUTPUT_FILE
    echo "$TOP_RAM_3" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Apache Status ====" >> $OUTPUT_FILE
    echo "$APACHE_STATUS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 20 IPs Client ====" >> $OUTPUT_FILE
    echo "$TOP_IPS_CLIENT" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 20 Virtual Hosts ====" >> $OUTPUT_FILE
    echo "$TOP_VIRTUAL_HOSTS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top 20 Requests ====" >> $OUTPUT_FILE
    echo "$TOP_REQUESTS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== MySQL Connection Status ====" >> $OUTPUT_FILE
    echo -e "$MYSQL_CONNECTION" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== MySQL InnoDB Status ====" >> $OUTPUT_FILE
    echo -e "$MYSQL_INNODB" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "MySQL Total Running Query: $MYSQL_RUN" >> $OUTPUT_FILE
    echo "MySQL Total Sleep/NULL Query: $MYSQL_SLEEP" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== MySQL Running Query ====" >> $OUTPUT_FILE
    echo "$MYSQL_QUERY" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Apache / MySQL Restart Logs ====" >> $OUTPUT_FILE
    echo "$APACHE_LOGS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "$MYSQL_LOGS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top I/O Processes ====" >> $OUTPUT_FILE
    echo "$TOP_PROCESSES_IO" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Out Of Memory Logs ====" >> $OUTPUT_FILE
    echo "$OOM" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top Email Queue ====" >> $OUTPUT_FILE
    echo "Total Queue: $QUEUE" >> $OUTPUT_FILE
    echo "Top Sender Queue:" >> $OUTPUT_FILE
    echo "$TOP_QUEUE" >> $OUTPUT_FILE
    echo "-------------------------------------------------------------------------------------" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE

    # Delete log files older than 7 days
    find $LOG_DIR -daystart -name "sysmon_*.log" -type f -mtime +7 -exec rm -f {} \;

    # Wait for the specified interval
    sleep $INTERVAL
done
