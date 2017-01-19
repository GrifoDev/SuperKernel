#!/system/bin/sh

# OpenRecoveryScript
# by UpInTheAir for SkyHigh kernels using Synapse & TWRP

# Busybox 
if [ -e /su/xbin/busybox ]; then
	BB=/su/xbin/busybox;
else if [ -e /sbin/busybox ]; then
	BB=/sbin/busybox;
else
	BB=/system/xbin/busybox;
fi;
fi;
TWRP=$(cat /res/synapse/Super/cron/twrp_backup);

if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;

if [ "$TWRP" == 1 ]; then

	# wait till CPU is idle.
	while [ ! "$($BB cat /proc/loadavg | cut -c1-4)" -lt "3.50" ]; do
		echo "Waiting For CPU to cool down";
		sleep 30;
	done;

	# append date-time suffix to backup (epoch format for TWRP compatibility)
	DATE=$(date +%s);

	# change to common integer unit (KB)
	KB=$((1024 * 1024));

	# system used (note: insert space after /system so we don't read /system/xbin)
	SYSTEM_USED=$(df | grep '^/system ' | awk '{print $3}');
	SYSTEM_USED=$(echo "${SYSTEM_USED%?} $KB" | awk '{printf "%.0f \n", $1*$2}');

	# data free
	DATA_FREE=$(df | grep '^/storage/emulated' | awk '{print $4}');
	DATA_FREE=$(echo "${DATA_FREE%?} $KB" | awk '{printf "%.0f \n", $1*$2}');

	# data used
	DATA_USED=$(df | grep '^/storage/emulated' | awk '{print $3}');
	DATA_USED=$(echo "${DATA_USED%?} $KB" | awk '{printf "%.0f \n", $1*$2}');

	# internal sdcard (storage)
	MEDIA_USED=$(du -hs /data/media/0);
	MEDIA_USED=$(echo "${MEDIA_USED%G*} $KB" | awk '{printf "%.0f \n", $1*$2}');

	# find oldest twrp_backup & calc size
	TWRP_BACKUP_DIR=$(ls -d /data/media/0/TWRP/BACKUPS/*);
	OLDEST_BACKUP_DIR=$(find $TWRP_BACKUP_DIR/ -maxdepth 1 -type d -name 'twrp_backup-*' -print0 | sort -z | tr '\0\n' '\n\0' 2>/dev/null | head -1 | tr '\0\n' '\n\0');
	OLDEST_BACKUP=$(du -hs $OLDEST_BACKUP_DIR);
	OLDEST_BACKUP=$(echo "${OLDEST_BACKUP%G*} $KB" | awk '{printf "%.0f \n", $1*$2}');

	# boot size in KB for N920* G928* (28MB)
	BOOT=28672;

	# total backup size (approx)
	BACKUP=$(($SYSTEM_USED + $(($DATA_USED - $MEDIA_USED)) + $BOOT));

	# check for available free space on internal storage for backup
	# (note: this does NOT take into account any TWRP compression)
	if [ "$DATA_FREE" -gt "$BACKUP" ]; then

		# clean app cache
		CACHE_JUNK=$(ls -d /data/data/*/cache)
		for i in $CACHE_JUNK; do
			rm -rf "$i"/*
		done;

		# remove old logs
		rm -rf /cache/lost+found/*
		rm -rf /data/anr/*
		rm -rf /data/clipboard/*
		rm -rf /data/lost+found/*
		rm -rf /data/system/dropbox/*
		rm -rf /data/tombstones/*

		date +%R-%F > /data/crontab/cron-clear-file-cache;
		echo " Cleaned Apps Cache" >> /data/crontab/cron-clear-file-cache;

		# disable dyn_fsync before sync
		if [[ "$(cat /sys/kernel/dyn_fsync/Dyn_fsync_active)" != "0" ]]; then
			echo "0" > /sys/kernel/dyn_fsync/Dyn_fsync_active;
		fi;

		# OpenRecoveryScript
		echo "set tw_disable_free_space 1" >> /cache/recovery/openrecoveryscript; # disable TWRP free space check
		echo "backup SDBOM twrp_backup-$DATE" >> /cache/recovery/openrecoveryscript;

		date +%R-%F > /data/crontab/cron-twrp_backup;
		echo " TWRP-auto-backup created" >> /data/crontab/cron-twrp_backup;

		$BB sync;
		$BB sleep 1;
		/system/bin/reboot recovery;

	# check if deleting oldest backup will create enough free space ('Delete TWRP Auto Backup' is ENABLED)
	elif [ $(($DATA_FREE + $OLDEST_BACKUP)) -gt "$BACKUP" ] && [[ "$(cat /res/synapse/Super/cron/twrp_backup_del)" == "1" ]]; then

		# delete oldest twrp_backup folder if it exists & create free space
		if [ -d $OLDEST_BACKUP_DIR ]; then
			rm -rf $OLDEST_BACKUP_DIR;
		fi;

		# clean app cache
		CACHE_JUNK=$(ls -d /data/data/*/cache)
		for i in $CACHE_JUNK; do
			rm -rf "$i"/*
		done;

		# remove old logs
		rm -rf /cache/lost+found/*
		rm -rf /data/anr/*
		rm -rf /data/clipboard/*
		rm -rf /data/lost+found/*
		rm -rf /data/system/dropbox/*
		rm -rf /data/tombstones/*

		date +%R-%F > /data/crontab/cron-clear-file-cache;
		echo " Cleaned Apps Cache" >> /data/crontab/cron-clear-file-cache;

		# disable dyn_fsync before fstrim & sync
		if [[ "$(cat /sys/kernel/dyn_fsync/Dyn_fsync_active)" != "0" ]]; then
			echo "0" > /sys/kernel/dyn_fsync/Dyn_fsync_active;
			$BB sync;
		fi;

		# fstrim EXT4 partitions after creating free space
		if grep -q 'system ext4' /proc/mounts ; then
			/system/xbin/fstrim -v /system
		else
			exit 0;
		fi;
		if grep -q 'data ext4' /proc/mounts ; then
			/system/xbin/fstrim -v /data
		else
			exit 0;
		fi;
		if grep -q 'cache ext4' /proc/mounts ; then
			/system/xbin/fstrim -v /cache
		else
			exit 0;
		fi;

		date +%R-%F > /data/crontab/cron-fstrim;
		echo " File System trimmed" >> /data/crontab/cron-fstrim;

		# OpenRecoveryScript
		echo "set tw_disable_free_space 1" >> /cache/recovery/openrecoveryscript; # disable TWRP free space check
		echo "backup SDBOM twrp_backup-$DATE" >> /cache/recovery/openrecoveryscript;


		date +%R-%F > /data/crontab/cron-twrp_backup;
		echo " TWRP-auto-backup created" >> /data/crontab/cron-twrp_backup;

		$BB sync;
		$BB sleep 1;
		/system/bin/reboot recovery;

	else
		echo " TWRP-auto-backup is aborted (no free space)" >> /data/crontab/cron-twrp_backup;
	fi;

elif [ "$TWRP" == 0 ]; then

	date +%R-%F > /data/crontab/cron-twrp_backup;
	echo " TWRP-auto-backup is disabled" >> /data/crontab/cron-twrp_backup;
fi;
