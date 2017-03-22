#!/system/bin/sh

# Remount file systems with lazytime
if [[ "$(cat /data/.Super/lazytime_mount)" == "1" ]]; then
	busybox sync;
	busybox mount -o remount,lazytime /cache;
	busybox mount -o remount,lazytime /data;
	busybox sync;
fi;

touch /dev/block/mounted;
