#!/system/bin/sh

# Setup for invisible_cpuset
if [[ "$(cat /data/.Super/invisible_cpuset)" == "1" ]]; then
	mkdir /dev/cpuset/invisible
	chown system:system /dev/cpuset/invisible
	chown system:system /dev/cpuset/invisible/tasks
	chmod 0755 /dev/cpuset/invisible
	chmod 0644 /dev/cpuset/invisible/tasks
	echo "0-7" > /dev/cpuset/invisible/cpus
	echo "0" > /dev/cpuset/invisible/mems
fi;
