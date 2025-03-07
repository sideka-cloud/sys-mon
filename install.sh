#!/bin/bash

# Add permission execute
chmod +x system_monitor.sh
chmod +x read.sh

# Copy file service
cp -r system_monitor.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable service system_monitor
systemctl enable system_monitor
systemctl start system_monitor

echo " "
echo "system_monitor was installed." 
echo " "
echo "Check status service: systemctl status system_monitor"
echo "Restart service: systemctl restart system_monitor"
echo " "
echo "Check logs files, example:"
echo "bash read.sh "2025-03-07 22:00:00" "2025-03-07 22:10:59""
echo " "
