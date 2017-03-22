#!/system/bin/sh

# Fuel guage reset script
# by UpInTheAir for SkyHigh kernels & Synapse

if [ -d "/sys/devices/battery" ]; then
	P=/sys/devices/battery
elif [ -d "/sys/devices/battery.54" ]; then
	P=/sys/devices/battery.54
elif [ -d "/sys/devices/battery.53" ]; then
	P=/sys/devices/battery.53
elif [ -d "/sys/devices/battery.52" ]; then
	P=/sys/devices/battery.52
elif [ -d "/sys/devices/battery.51" ]; then
	P=/sys/devices/battery.51
fi;

# Busybox 
if [ -e /su/xbin/busybox ]; then
	BB=/su/xbin/busybox;
else if [ -e /sbin/busybox ]; then
	BB=/sbin/busybox;
else
	BB=/system/xbin/busybox;
fi;
fi;
FG_RESET=$(cat /res/synapse/Super/cron/fg_reset);

if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;

if [ "$FG_RESET" == 1 ]; then

	$BB chmod 666 $P/power_supply/battery/fg_reset_cap;
	echo 1 > $P/power_supply/battery/fg_reset_cap;

	date +%R-%F > /data/crontab/cron-reset_battery;
	echo " Battery Reset" >> /data/crontab/cron-reset_battery;

elif [ "$FG_RESET" == 0 ]; then

	date +%R-%F > /data/crontab/cron-reset_battery;
	echo " Battery Reset is disabled" >> /data/crontab/cron-reset_battery;
fi;
