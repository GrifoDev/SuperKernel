#!/system/bin/sh

# Original by dorimanx for ExTweaks
# Modified by UpInTheAir for SkyHigh kernels & Synapse

BB=/system/xbin/busybox;
GOOGLE=$(cat /res/synapse/Super/cron/google);

if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;

if [ "$GOOGLE" == 1 ]; then

	if [ "$($BB pidof com.google.android.gms | wc -l)" -eq "1" ]; then
		$BB kill $($BB pidof com.google.android.gms);
	fi;
	if [ "$($BB pidof com.google.android.gms.unstable | wc -l)" -eq "1" ]; then
		$BB kill $($BB pidof com.google.android.gms.unstable);
	fi;
	if [ "$($BB pidof com.google.android.gms.persistent | wc -l)" -eq "1" ]; then
		$BB kill $($BB pidof com.google.android.gms.persistent);
	fi;
	if [ "$($BB pidof com.google.android.gms.wearable | wc -l)" -eq "1" ]; then
		$BB kill $($BB pidof com.google.android.gms.wearable);
	fi;

	date +%R-%F > /data/crontab/cron-ram-release;
	echo " Google RAM released" >> /data/crontab/cron-ram-release;

elif [ "$GOOGLE" == 0 ]; then

	date +%R-%F > /data/crontab/cron-ram-release;
	echo " Google RAM Release is disabled" >> /data/crontab/cron-ram-release;
fi;
