# System Monitor

Pre-Requirement:

- Compatible for CentOS/AlmaLinux with cPanel

Make sure sysstat and iotop was installed on your system:

- `yum install sysstat iotop -y`

Clone Repository:

- `git clone https://github.com/sideka-cloud/sys-mon.git && cd sys-mon`

#

Check this line on file: system_monitor.sh , then replace the /sda/ part with the disk name used on the system, e.g. /vda/ or /xda/

```
    # Get Disk Read/Write (KB/s)
    DISK_IO=$(iostat -d | awk '/sda/ {print $3, $4}')
```

Install system_monitor: 

- `bash install.sh`


Check logs system_monitor, example:

- `bash read.sh "2025-03-07 22:00:00" "2025-03-07 22:10:00"`

Cek status service system_monitor

- `systemctl status system_monitor`

Restart service system_monitor

- `systemctl restart system_monitor`

#
Example logs files:

![Alt text](img/1.png)

![Alt text](img/2.png)

![Alt text](img/3.png)
