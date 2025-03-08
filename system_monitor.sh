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
    MYSQL_CONNECTION=$(echo "Current Connections: $(mysql -Nse "SHOW STATUS WHERE Variable_name = 'Threads_connected'" | awk '{print $2}')")
    MYSQL_CONNECTION="$MYSQL_CONNECTION\nMax Used Connections: $(mysql -Nse "SHOW STATUS WHERE Variable_name = 'Max_used_connections'" | awk '{print $2}')"
    MYSQL_CONNECTION="$MYSQL_CONNECTION\nMax Allowed Connections: $(mysql -Nse "SHOW VARIABLES WHERE Variable_name = 'max_connections'" | awk '{print $2}')"

    # Get MySQL InnoDB status
    MYSQL_INNODB=$(echo "InnoDB Buffer Pool Size: $(mysql -Nse "SHOW VARIABLES WHERE Variable_name = 'innodb_buffer_pool_size'" | awk '{printf "%.2f GB\n", $2 / (1024*1024*1024)}')")
    MYSQL_INNODB="$MYSQL_INNODB\nInnoDB Buffer Pool Usage: $(mysql -Nse "SHOW STATUS WHERE Variable_name IN ('Innodb_buffer_pool_pages_total', 'Innodb_buffer_pool_pages_free')" | awk '{a[$1]=$2} END {printf "%.2f%%\n", 100*(1 - a["Innodb_buffer_pool_pages_free"] / a["Innodb_buffer_pool_pages_total"]) }')"

    # Get MySQL query status
    MYSQL_QUERY=$(mysql -e "SHOW FULL PROCESSLIST" | head -n 30)

    # Get Apache and MySQL logs
    APACHE_LOGS=$(journalctl -u httpd --no-pager -n 10)
    MYSQL_LOGS=$(journalctl -u mysqld --no-pager -n 10)

    # Get I/O status
    TOP_PROCESSES_IO=$(iotop -b -n 2 -o -P -k | awk '!/Total DISK READ/ && !/Actual DISK READ/ && !seen[$0]++' | awk '{print substr($0, 1, 140)}')

    # Append the data to the output file
    echo "=================================" >> $OUTPUT_FILE
    echo "Timestamp: $TIMESTAMP" >> $OUTPUT_FILE
    echo "CPU Usage (All Core): $CPU_USAGE%" >> $OUTPUT_FILE
    echo "Load Average (1m, 5m, 15m): $LOAD_AVERAGE" >> $OUTPUT_FILE
    echo "RAM Usage: $RAM_USAGE MB" >> $OUTPUT_FILE
    echo "Swap Usage: $SWAP_USAGE MB" >> $OUTPUT_FILE
    echo "Disk R/W: $DISK_IO KB/s" >> $OUTPUT_FILE
    echo "Network Up/Down: $NETWORK_IO KB/s" >> $OUTPUT_FILE
    echo "=================================" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "Top 15 Processes by CPU Usage:" >> $OUTPUT_FILE
    echo "$TOP_PROCESSES_CPU" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "Top 15 Processes by RAM Usage:" >> $OUTPUT_FILE
    echo "$TOP_PROCESSES_RAM" >> $OUTPUT_FILE
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
    echo "==== MySQL Query Status ====" >> $OUTPUT_FILE
    echo "$MYSQL_QUERY" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Apache / MySQL Restart Logs ====" >> $OUTPUT_FILE
    echo "$APACHE_LOGS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "$MYSQL_LOGS" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE
    echo "==== Top I/O Processes ====" >> $OUTPUT_FILE
    echo "$TOP_PROCESSES_IO" >> $OUTPUT_FILE
    echo "-------------------------------------------------------------------------------------" >> $OUTPUT_FILE
    echo " " >> $OUTPUT_FILE

    # Delete log files older than 7 days
    find $LOG_DIR -name "sysmon_*.log" -type f -mtime +7 -exec rm -f {} \;

    # Wait for the specified interval
    sleep $INTERVAL
done
