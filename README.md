SysSnap
=======

A helpful utility for system performance monitoring and troubleshooting server load issues.

sys-snap.sh is deprecated, please use sys-snap.pl instead.


Intent of Script
=======
System Snapshot is a handy script that logs data from these locations:

- /proc/loadavg
- /proc/meminfo
- mstat 1 10
- ps auwwxf
- netstat -anp
- mysqladmin proc
- localhost/whm-server-status
- http://localhost/server-status
- lsof


Usage
=======

nohup perl sys-snap.pl &

The script logs to /root/system-snapshot

To stop sys-snap.pl, kill the process:
    ps aux | awk '/[s]ys-snap/ {print$2}' | xargs kill
