#!/bin/bash

echo "=== Install sysstat, iotop, elinks ==="
yum install sysstat iotop elinks -y
echo " "
check_package() {
    PACKAGE=$1
    if rpm -q "$PACKAGE" &>/dev/null; then
        echo "$PACKAGE is installed"
    else
        echo "$PACKAGE is NOT installed"
    fi
}
echo "=== Check if sysstat and iotop were installed ==="
check_package "sysstat"
check_package "iotop"
echo " "
echo "=== Install system_monitor ==="

# Add permission execute
chmod +x system_monitor.sh
chmod +x read.sh

# Copy file service
cp -r system_monitor_plesk.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable service system_monitor
systemctl enable system_monitor_plesk
systemctl start system_monitor_plesk

# Reconfigure apachectl
sed -i 's/STATUSURL="http:\/\/localhost:80\/server-status"/STATUSURL="http:\/\/localhost:7080\/server-status"/g' /usr/sbin/apachectl

echo " "
echo "=== System_monitor was installed ===" 
echo " "
echo "=== Check status service ==="
echo "systemctl status system_monitor_plesk"
echo " "
echo "=== Check logs files, example: ==="
echo "bash read.sh "2025-03-07 22:00:00" "2025-03-07 22:10:00""
echo " "
