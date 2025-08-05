<h1 align="center">System Monitor</h1>

### About sys-mon:

Sys-mon is a simple system monitoring to check system process activity on RHEL-based Linux using the cPanel and Plesk panel application. This tool will check every 60 seconds regarding CPU usage, average load, RAM usage, disk, and network activity. In addition, it will also check in detail which application processes use quite high CPU and RAM, total IPs that often access the web server, total virtual hosts that are often accessed, total requests that are often accessed, total database connection usage, innodb usage, and database query activity. In addition, the last log of apache and MySQL restart activity, disk I/O usage activity, and the last out-of-memory and top email queue.

#

### Pre-Requirement

Operating System Compatibility:
- CentOS 7 (full support)
- AlmaLinux 8 (full support)
- AlmaLinux 9 (partial support | apache function not support)

Control Panel Compatibility:
- cPanel
- Plesk


#
### Clone Repository

- `git clone https://github.com/sideka-cloud/sys-mon.git && cd sys-mon`

#
### How to Install for cPanel

Install system_monitor: 

- `bash install.sh`

Cek status service system_monitor:

- `systemctl status system_monitor`

Restart service system_monitor:

- `systemctl restart system_monitor`


#
### How to Install for Plesk

Install system_monitor_plesk: 

- `bash install_plesk.sh`

Cek status service system_monitor:

- `systemctl status system_monitor_plesk`

Restart service system_monitor:

- `systemctl restart system_monitor_plesk`

#
Check logs system_monitor, example:

- `bash read.sh "2025-03-07 22:00:00" "2025-03-07 22:10:00"`

Log directory:

- `/var/log/system_monitor`

#
### How to Un-install

Stop and disable service

- `systemctl stop system_monitor`
- `systemctl disable system_monitor`

Remove service and Remove logs

- `rm -rf /etc/systemd/system/system_monitor.service`
- `rm -rf /var/log/system_monitor`

#
### Example logs files:

![Alt text](img/1.png)

![Alt text](img/2.png)

![Alt text](img/3.png)
