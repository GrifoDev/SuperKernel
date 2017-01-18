#!/sbin/busybox sh

# Credits:
# Zacharias.maladroit
# Voku1987
# Collin_ph@xda
# Dorimanx@xda
# Gokhanmoral@xda
# Johnbeetee
# halaszk@xda
# UpInTheAir@xda
# Neobuddy@xda
# Alucard24@xda

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# read setting from profile to boot value
cortexbrain_background_process=$(cat /res/synapse/Super/cortexbrain_background_process);
cortexbrain_kernel=$(cat /res/synapse/Super/cortexbrain_kernel);
cortexbrain_system=$(cat /res/synapse/Super/cortexbrain_system);
cortexbrain_wifi_auto=$(cat /res/synapse/Super/cortexbrain_wifi_auto);
cortexbrain_wifi_auto_scron=$(cat /res/synapse/Super/cortexbrain_wifi_auto_scron);
cortexbrain_wifi_auto_scroff=$(cat /res/synapse/Super/cortexbrain_wifi_auto_scroff);
cortexbrain_wifi_delay_scron_enable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scron_enable) * 60 ));
cortexbrain_wifi_delay_scron_disable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scron_disable) * 360 ));
cortexbrain_wifi_delay_scroff_enable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scroff_enable) * 60 ));
cortexbrain_wifi_delay_scroff_disable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scroff_disable) * 360 ));
cortexbrain_media_manager=$(cat /res/synapse/Super/cortexbrain_media_manager);
cortexbrain_nmi_auto=$(cat /res/synapse/Super/cortexbrain_nmi_auto);
cortexbrain_doze_auto=$(cat /res/synapse/Super/cortexbrain_doze_auto);
cortexbrain_alpm_auto=$(cat /res/synapse/Super/cortexbrain_alpm_auto);
cortexbrain_lux=$(cat /res/synapse/Super/cortexbrain_lux);
cortexbrain_power_aware_sched=$(cat /res/synapse/Super/cortexbrain_power_aware_sched);
cortexbrain_hmp_little_pack=$(cat /res/synapse/Super/cortexbrain_hmp_little_pack);
cortexbrain_pewq=$(cat /res/synapse/Super/cortexbrain_pewq);

# ==============================================================
# GLOBAL VARIABLES || without "local" also a variable in a function is global
# ==============================================================

BB=/sbin/busybox;

if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;

FILE_NAME=$0;
PIDOFCORTEX=$$;

# Check if dumpsys exist in ROM
if [ -e /system/bin/dumpsys ]; then
	DUMPSYS=1;
else
	DUMPSYS=0;
fi;

READ_CONFIG()
{
cortexbrain_background_process=$(cat /res/synapse/Super/cortexbrain_background_process);
cortexbrain_kernel=$(cat /res/synapse/Super/cortexbrain_kernel);
cortexbrain_system=$(cat /res/synapse/Super/cortexbrain_system);
cortexbrain_wifi_auto=$(cat /res/synapse/Super/cortexbrain_wifi_auto);
cortexbrain_wifi_auto_scron=$(cat /res/synapse/Super/cortexbrain_wifi_auto_scron);
cortexbrain_wifi_auto_scroff=$(cat /res/synapse/Super/cortexbrain_wifi_auto_scroff);
cortexbrain_wifi_delay_scron_enable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scron_enable) * 60 ));
cortexbrain_wifi_delay_scron_disable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scron_disable) * 360 ));
cortexbrain_wifi_delay_scroff_enable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scroff_enable) * 60 ));
cortexbrain_wifi_delay_scroff_disable=$(($(cat /res/synapse/Super/cortexbrain_wifi_delay_scroff_disable) * 360 ));
cortexbrain_media_manager=$(cat /res/synapse/Super/cortexbrain_media_manager);
cortexbrain_nmi_auto=$(cat /res/synapse/Super/cortexbrain_nmi_auto);
cortexbrain_doze_auto=$(cat /res/synapse/Super/cortexbrain_doze_auto);
cortexbrain_alpm_auto=$(cat /res/synapse/Super/cortexbrain_alpm_auto);
cortexbrain_lux=$(cat /res/synapse/Super/cortexbrain_lux);
cortexbrain_power_aware_sched=$(cat /res/synapse/Super/cortexbrain_power_aware_sched);
cortexbrain_hmp_little_pack=$(cat /res/synapse/Super/cortexbrain_hmp_little_pack);
cortexbrain_pewq=$(cat /res/synapse/Super/cortexbrain_pewq);
log -p i -t "$FILE_NAME" "*** CONFIG ***: READED";
}

# Please don't kill "cortexbrain"
DONT_KILL_CORTEX()
{
	PIDOFCORTEX=$(pgrep -f "/sbin/cortexbrain-tune.sh");
	for i in $PIDOFCORTEX; do
		echo "-950" > /proc/${i}/oom_score_adj;
	done;

	log -p i -t "$FILE_NAME" "*** DONT_KILL_CORTEX ***";
}

# ==============================================================
# KERNEL-TWEAKS
# ==============================================================
KERNEL_TWEAKS()
{
	if [ "$cortexbrain_kernel" == "1" ]; then
		echo "0" > /proc/sys/vm/oom_kill_allocating_task;
		echo "0" > /proc/sys/vm/panic_on_oom;
		echo "30" > /proc/sys/kernel/panic;
		echo "0" > /proc/sys/kernel/panic_on_oops;

		log -p i -t "$FILE_NAME" "*** KERNEL_TWEAKS ***: enabled";
	else
		echo "kernel_tweaks disabled";
	fi;
}
KERNEL_TWEAKS;

# ==============================================================
# SYSTEM-TWEAKS
# ==============================================================
SYSTEM_TWEAKS()
{
	if [ "$cortexbrain_system" == "1" ]; then
		setprop windowsmgr.max_events_per_sec 240;

		log -p i -t "$FILE_NAME" "*** SYSTEM_TWEAKS ***: enabled";
	else
		echo "system_tweaks disabled";
	fi;
}
SYSTEM_TWEAKS;

# ==============================================================
# SCREEN-FUNCTIONS
# ==============================================================
WIFI_AUTO()
{
	if [ "$cortexbrain_wifi_auto" == "1" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then

			# Check WIFI state
			WIFI_STATE=$(dumpsys wifi | awk '/Wi-Fi is/ {print $3}');

			if [ "$WIFI_STATE" == "disabled" ]; then
				svc wifi enable 2> /dev/null;
			fi;

		elif [ "${state}" == "sleep" ]; then

			# Check WIFI state
			WIFI_STATE=$(dumpsys wifi | awk '/Wi-Fi is/ {print $3}');

			if [ "$WIFI_STATE" == "enabled" ]; then
				svc wifi disable 2> /dev/null;
			fi;
		fi;

		log -p i -t "$FILE_NAME" "*** WIFI_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** WIFI_AUTO: Disabled ***";
	fi;
}

WIFI_AUTO_SCREEN_ON()
{
	if [ "$cortexbrain_wifi_auto_scron" == "1" ] && [ "$cortexbrain_wifi_auto" != "1" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then

			# Log file location
			LOG_FILE=/data/.wifi_scron.log;

			# Get the last modify date of the log file. If the file does not exist, set value to 0
			if [ -e $LOG_FILE ]; then
				LASTRUN=$(date +%s -r $LOG_FILE);
			else
				LASTRUN=0;
			fi;

			# Get current date in epoch format
			CURRDATE=$(date +%s);

			# Check the interval
			INTERVAL=$(($CURRDATE - $LASTRUN));

			# If interval is more than the set one, then run the main script
			if [ "$INTERVAL" -gt "$cortexbrain_wifi_delay_scron_disable" ]; then

				# Check WIFI state
				WIFI_STATE=$(dumpsys wifi | awk '/Wi-Fi is/ {print $3}');

				if [ "$WIFI_STATE" == "disabled" ]; then

					svc wifi enable 2> /dev/null;

					echo "WIFI_AUTO_SCREEN_ON enabled at $( date +"%m-%d-%Y %H:%M:%S" )" | tee -a $LOG_FILE;
				fi;
			fi;

			# Log file location
			LOG_FILE=/data/.wifi_scron.log;

			# Get the last modify date of the log file. If the file does not exist, set value to 0
			if [ -e $LOG_FILE ]; then
				LASTRUN=$(date +%s -r $LOG_FILE);
			else
				LASTRUN=0;
			fi;

			# Get current date in epoch format
			CURRDATE=$(date +%s);

			# Check the interval
			INTERVAL=$(($CURRDATE - $LASTRUN));

			if [ "$INTERVAL" -gt "$cortexbrain_wifi_delay_scron_enable" ]; then

				# Check WIFI state
				WIFI_STATE=$(dumpsys wifi | awk '/Wi-Fi is/ {print $3}');

				if [ "$WIFI_STATE" == "enabled" ]; then

					svc wifi disable 2> /dev/null;

					echo "WIFI_AUTO_SCREEN_ON disabled at $( date +"%m-%d-%Y %H:%M:%S" )" | tee -a $LOG_FILE;
				fi;

			fi;
		else
			exit 0;
		fi;

		log -p i -t "$FILE_NAME" "*** WIFI_AUTO_SCREEN_ON ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** WIFI_AUTO_SCREEN_ON: Disabled ***";
	fi;
}

WIFI_AUTO_SCREEN_OFF()
{
	if [ "$cortexbrain_wifi_auto_scroff" == "1" ] && [ "$cortexbrain_wifi_auto" != "1" ]; then

		local state="$1";

		if [ "${state}" == "sleep" ]; then

			# Log file location
			LOG_FILE=/data/.wifi_scroff.log;

			# Get the last modify date of the log file. If the file does not exist, set value to 0
			if [ -e $LOG_FILE ]; then
				LASTRUN=$(date +%s -r $LOG_FILE);
			else
				LASTRUN=0;
			fi;

			# Get current date in epoch format
			CURRDATE=$(date +%s);

			# Check the interval
			INTERVAL=$(($CURRDATE - $LASTRUN));

			# If interval is more than the set one, then run the main script
			if [ "$INTERVAL" -gt "$cortexbrain_wifi_delay_scroff_disable" ]; then

				# Check WIFI state
				WIFI_STATE=$(dumpsys wifi | awk '/Wi-Fi is/ {print $3}');

				if [ "$WIFI_STATE" == "disabled" ]; then

					svc wifi enable 2> /dev/null;

					echo "WIFI_AUTO_SCREEN_OFF enabled at $( date +"%m-%d-%Y %H:%M:%S" )" | tee -a $LOG_FILE;
				fi;
			fi;

			# Log file location
			LOG_FILE=/data/.wifi_scroff.log;

			# Get the last modify date of the log file. If the file does not exist, set value to 0
			if [ -e $LOG_FILE ]; then
				LASTRUN=$(date +%s -r $LOG_FILE);
			else
				LASTRUN=0;
			fi;

			# Get current date in epoch format
			CURRDATE=$(date +%s);

			# Check the interval
			INTERVAL=$(($CURRDATE - $LASTRUN));

			if [ "$INTERVAL" -gt "$cortexbrain_wifi_delay_scroff_enable" ]; then

				# Check WIFI state
				WIFI_STATE=$(dumpsys wifi | awk '/Wi-Fi is/ {print $3}');

				if [ "$WIFI_STATE" == "enabled" ]; then

					svc wifi disable 2> /dev/null;

					echo "WIFI_AUTO_SCREEN_OFF disabled at $( date +"%m-%d-%Y %H:%M:%S" )" | tee -a $LOG_FILE;
				fi;

			fi;
		else
			exit 0;
		fi;

		log -p i -t "$FILE_NAME" "*** WIFI_AUTO_SCREEN_OFF ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** WIFI_AUTO_SCREEN_OFF: Disabled ***";
	fi;
}

MEDIA_MANAGER()
{
	if [ "$cortexbrain_media_manager" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then
			pm enable com.android.providers.media/com.android.providers.media.MediaScannerReceiver;
		elif [ "${state}" == "sleep" ]; then
			pm disable com.android.providers.media/com.android.providers.media.MediaScannerReceiver;
		fi;

		log -p i -t "$FILE_NAME" "*** MEDIA_MANAGER ***: ${state}";
	else
		log -p i -t "$FILE_NAME" "*** MEDIA_MANAGER: User-Mode ***";
	fi;
}

NMI_AUTO()
{
	if [ "$cortexbrain_nmi_auto" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then
			echo "1" > /proc/sys/kernel/nmi_watchdog;
		elif [ "${state}" == "sleep" ]; then
			echo "0" > /proc/sys/kernel/nmi_watchdog;
		fi;

		log -p i -t "$FILE_NAME" "*** NMI_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** NMI_AUTO: Disabled ***";
	fi;
}

DOZE_AUTO()
{
	if [ "$cortexbrain_doze_auto" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then
			$BB sync;
			dumpsys deviceidle step
		elif [ "${state}" == "sleep" ]; then
			$BB sync;
			dumpsys deviceidle force-idle;
		fi;

		log -p i -t "$FILE_NAME" "*** DOZE_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** DOZE_AUTO: Disabled ***";
	fi;
}

ALPM_AUTO()
{
	if [ "$cortexbrain_alpm_auto" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then
			# Check if edge panel or Always on Display are active
			EDGE_STATUS=$(dumpsys window windows | awk '/mCurrentFocus/ {print $4}');
			if [ "$EDGE_STATUS" != "StatusBar}" ]; then
				ALPM_STATE=$(cat /sys/class/lcd/panel/alpm);
				if [ "$ALPM_STATE" != "0" ]; then
					echo "0" > /sys/class/lcd/panel/alpm;
				fi;
			fi;
		elif [ "${state}" == "sleep" ]; then
			# Check if edge panel or Always on Display are active
			EDGE_STATUS=$(dumpsys window windows | awk '/mCurrentFocus/ {print $4}');
			# Read light sensor (lux) value.
			LUX=$(dumpsys display | awk '/mAmbientLux/ {print $1}' | cut -d"=" -f2);
			# Round lux value to a whole number so it is readable
			LUX="$($BB printf "%.0f" $LUX)";

			if [ "$EDGE_STATUS" == "CocktailBarBlockScreen}" ] || [ "$EDGE_STATUS" == "StatusBar}" ] && [ "$LUX" -lt "$cortexbrain_lux" ]; then
				ALPM_STATE=$(cat /sys/class/lcd/panel/alpm);
				if [ "$ALPM_STATE" != "1" ]; then
					echo "1" > /sys/class/lcd/panel/alpm;
				fi;

				log -p i -t "$FILE_NAME" "*** ALPM_AUTO ***: In range == SENSOR $LUX < USER $cortexbrain_lux ***: done";
			else
				ALPM_STATE=$(cat /sys/class/lcd/panel/alpm);
				if [ "$ALPM_STATE" != "0" ]; then
					echo "0" > /sys/class/lcd/panel/alpm;
				fi;

				log -p i -t "$FILE_NAME" "*** ALPM_AUTO ***: Out of range == SENSOR $LUX > USER $cortexbrain_lux ***: done";
			fi;
		fi;

		log -p i -t "$FILE_NAME" "*** ALPM_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** ALPM_AUTO: Disabled ***";
	fi;
}

POWER_AWARE_SCHED_AUTO()
{
	if [ "$cortexbrain_power_aware_sched" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then

			# Check Power Aware State
			POWER_AWARE_SCHED_STATE=$(cat /sys/kernel/hmp/power_migration);

			if [ "$POWER_AWARE_SCHED_STATE" != "0" ]; then
				echo "0" > /sys/kernel/hmp/power_migration;
			fi;

		elif [ "${state}" == "sleep" ]; then

			# Check Power Aware State
			POWER_AWARE_SCHED_STATE=$(cat /sys/kernel/hmp/power_migration);

			if [ "$POWER_AWARE_SCHED_STATE" != "1" ]; then
				echo "1" > /sys/kernel/hmp/power_migration;
			fi;
		fi;

		log -p i -t "$FILE_NAME" "*** POWER_AWARE_SCHED_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** POWER_AWARE_SCHED_AUTO: Disabled ***";
	fi;
}

HMP_LITTLE_PACK_AUTO()
{
	if [ "$cortexbrain_hmp_little_pack" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then

			# Check HMP Packing State
			HMP_LITTLE_PACK_STATE=$(cat /sys/kernel/hmp/packing_enable);

			if [ "$HMP_LITTLE_PACK_STATE" != "0" ]; then
				echo "0" > /sys/kernel/hmp/packing_enable;
			fi;

		elif [ "${state}" == "sleep" ]; then

			# Check HMP Packing State
			HMP_LITTLE_PACK_STATE=$(cat /sys/kernel/hmp/packing_enable);

			if [ "$HMP_LITTLE_PACK_STATE" != "1" ]; then
				echo "1" > /sys/kernel/hmp/packing_enable;
			fi;
		fi;

		log -p i -t "$FILE_NAME" "*** HMP_LITTLE_PACK_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** HMP_LITTLE_PACK_AUTO: Disabled ***";
	fi;
}

PEWQ_AUTO()
{
	if [ "$cortexbrain_pewq" == "2" ]; then

		local state="$1";

		if [ "${state}" == "awake" ]; then

			# Check PEWQ State
			PEWQ_STATE=$(cat /sys/module/workqueue/parameters/power_efficient);

			if [ "$PEWQ_STATE" != "N" ]; then
				echo "N" > /sys/module/workqueue/parameters/power_efficient;
			fi;

		elif [ "${state}" == "sleep" ]; then

			# Check PEWQ State
			PEWQ_STATE=$(cat /sys/module/workqueue/parameters/power_efficient);

			if [ "$PEWQ_STATE" != "Y" ]; then
				echo "Y" > /sys/module/workqueue/parameters/power_efficient;
			fi;
		fi;

		log -p i -t "$FILE_NAME" "*** PEWQ_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** PEWQ_AUTO: Disabled ***";
	fi;
}

# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	READ_CONFIG;

	DONT_KILL_CORTEX;

	MEDIA_MANAGER "awake";

	NMI_AUTO "awake";

	DOZE_AUTO "awake";

	ALPM_AUTO "awake";

	POWER_AWARE_SCHED_AUTO "awake";

	HMP_LITTLE_PACK_AUTO "awake";

	PEWQ_AUTO "awake";

	if [ "$DUMPSYS" == 1 ]; then
	# Check the data state, DATA_DISABLED = 0, DATA_ENABLED = 2
	DATA_STATE=$(dumpsys telephony.registry | awk '/mDataConnectionState/ {print $1}');
		if [ "$DATA_STATE" == "mDataConnectionState=2" ]; then
			DATA_STATE=2;
		else
			DATA_STATE=0;
		fi;
	else
		DATA_STATE=0;
	fi;

	if [ "$DATA_STATE" == 0 ]; then

		WIFI_AUTO "awake";

		WIFI_AUTO_SCREEN_ON "awake";

		log -p i -t "$FILE_NAME" "*** AWAKE mode ***";

	else

		log -p i -t "$FILE_NAME" "*** On Data! AWAKE aborted! ***";

	fi;

	log -p i -t "$FILE_NAME" "*** AWAKE: Normal-Mode ***";

}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	READ_CONFIG;

	MEDIA_MANAGER "sleep";

	NMI_AUTO "sleep";

	if [ "$DUMPSYS" == 1 ]; then
		# Check the call state, CALL_STATE_IDLE (not on call) = 0, CALL_STATE_RINGING = 1, CALL_STATE_OFFHOOK (on call) = 2
		CALL_STATE=$(dumpsys telephony.registry | awk '/mCallState/ {print $1}');
		if [ "$CALL_STATE" == "mCallState=0" ]; then
			CALL_STATE=0;
		else
			CALL_STATE=2;
		fi;
	else
		CALL_STATE=0;
	fi;

	if [ "$CALL_STATE" == 0 ]; then

		WIFI_AUTO "sleep";

		WIFI_AUTO_SCREEN_OFF "sleep";

		DOZE_AUTO "sleep";

		ALPM_AUTO "sleep";

		POWER_AWARE_SCHED_AUTO "sleep";

		HMP_LITTLE_PACK_AUTO "sleep";

		PEWQ_AUTO "sleep";

		log -p i -t "$FILE_NAME" "*** SLEEP mode ***";

	else

		log -p i -t "$FILE_NAME" "*** On Call! SLEEP aborted! ***";

	fi;

	log -p i -t "$FILE_NAME" "*** SLEEP: Normal-Mode ***";

}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;

if [ "$cortexbrain_background_process" -eq "1" ] && [ "$(pgrep -f "/sbin/cortexbrain-tune.sh" | wc -l)" -eq "2" ]; then
	(while true; do
		sleep "3";

		SCREEN_OFF=$(cat /sys/class/backlight/panel/brightness);

		if [ "$SCREEN_OFF" != 0 ]; then
			# AWAKE State. all system ON
			AWAKE_MODE;

		elif [ "$SCREEN_OFF" == 0 ]; then
			# SLEEP state. All system to power save
			SLEEP_MODE;
		fi;
	done &);
else
	if [ "$cortexbrain_background_process" -eq "0" ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;
