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

echo "system_monitor was installed." 
echo " "
