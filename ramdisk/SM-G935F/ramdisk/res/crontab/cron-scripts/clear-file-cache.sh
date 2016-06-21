#!/system/bin/sh

# Clear Cache script
# Original by dorimanx for ExTweaks
# Modified by UpInTheAir for SkyHigh kernels & Synapse

BB=/system/xbin/busybox;
CACHE=$(cat /res/synapse/Super/cron_cache);

if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;

if [ "$CACHE" == 1 ]; then

	# wait till CPU is idle.
	while [ ! "$($BB cat /proc/loadavg | cut -c1-4)" -lt "3.50" ]; do
		echo "Waiting For CPU to cool down";
		sleep 30;
	done;

	CACHE_JUNK=$(ls -d /data/data/*/cache)
	for i in $CACHE_JUNK; do
		rm -rf "$i"/*
	done;

	# Old logs
	rm -rf /cache/lost+found/*
	rm -rf /data/anr/*
	rm -rf /data/clipboard/*
	rm -rf /data/lost+found/*
	rm -rf /data/system/dropbox/*
	rm -rf /data/tombstones/*
	$BB sync;

	date +%R-%F > /data/crontab/cron-clear-file-cache;
	echo " Cleaned Apps Cache" >> /data/crontab/cron-clear-file-cache;
	sync;

elif [ "$CACHE" == 0 ]; then

	date +%R-%F > /data/crontab/cron-clear-file-cache;
	echo " Clean file-cache is disabled" >> /data/crontab/cron-clear-file-cache;
fi;

$BB mount -t rootfs -o remount,ro rootfs;
