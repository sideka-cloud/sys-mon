#!/bin/bash

# Log directory
LOG_DIR="/var/log/system_monitor"

# Input start and end timestamps
START_TIME="$1"
END_TIME="$2"

# Find the log file for the given date
LOG_DATE=$(date -d "$START_TIME" "+%d%b" | tr '[:upper:]' '[:lower:]')
LOG_FILE="$LOG_DIR/sysmon_${LOG_DATE}.log"

# Check if the log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Log file for $LOG_DATE not found: $LOG_FILE"
    exit 1
fi

# Filter logs between the start and end timestamps
awk -v start="$START_TIME" -v end="$END_TIME" '
/Timestamp:/ {
    if ($2 " " $3 >= start && $2 " " $3 <= end) {
        print_line = 1
    } else {
        print_line = 0
    }
}
print_line == 1 { print }
' "$LOG_FILE"
