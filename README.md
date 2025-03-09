<h1 align="center">System Monitor</h1>

### About Tools:

This 

### Pre-Requirement:

- Compatible for CentOS/AlmaLinux with cPanel

Make sure sysstat and iotop was installed on your system:

- `yum install sysstat iotop -y`

Clone Repository:

- `git clone https://github.com/sideka-cloud/sys-mon.git && cd sys-mon`

#
### How to Install:

Install system_monitor: 

- `bash install.sh`


Check logs system_monitor, example:

- `bash read.sh "2025-03-07 22:00:00" "2025-03-07 22:10:00"`

Cek status service system_monitor

- `systemctl status system_monitor`

Restart service system_monitor

- `systemctl restart system_monitor`

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
