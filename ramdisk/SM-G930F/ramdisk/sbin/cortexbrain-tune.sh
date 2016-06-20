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

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# read setting from profile to boot value
cortexbrain_background_process=$(cat /res/synapse/Super/cortexbrain_background_process);
cortexbrain_kernel=$(cat /res/synapse/Super/cortexbrain_kernel);
cortexbrain_system=$(cat /res/synapse/Super/cortexbrain_system);
cortexbrain_wifi_auto=$(cat /res/synapse/Super/cortexbrain_wifi_auto);
cortexbrain_media_manager=$(cat /res/synapse/Super/cortexbrain_media_manager);
cortexbrain_nmi_auto=$(cat /res/synapse/Super/cortexbrain_nmi_auto);
cortexbrain_doze_auto=$(cat /res/synapse/Super/cortexbrain_doze_auto);
cortexbrain_alpm_auto=$(cat /res/synapse/Super/cortexbrain_alpm_auto);
cortexbrain_lux=$(cat /res/synapse/Super/cortexbrain_lux);

# ==============================================================
# GLOBAL VARIABLES || without "local" also a variable in a function is global
# ==============================================================

BB=/system/xbin/busybox;

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
cortexbrain_media_manager=$(cat /res/synapse/Super/cortexbrain_media_manager);
cortexbrain_nmi_auto=$(cat /res/synapse/Super/cortexbrain_nmi_auto);
cortexbrain_doze_auto=$(cat /res/synapse/Super/cortexbrain_doze_auto);
cortexbrain_alpm_auto=$(cat /res/synapse/Super/cortexbrain_alpm_auto);
cortexbrain_lux=$(cat /res/synapse/Super/cortexbrain_lux);
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
			svc wifi enable 2> /dev/null;
		elif [ "${state}" == "sleep" ]; then
			svc wifi disable 2> /dev/null;
		fi;

		log -p i -t "$FILE_NAME" "*** WIFI_AUTO ***: $state ***: done";
	else
		log -p i -t "$FILE_NAME" "*** WIFI_AUTO: Disabled ***";
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

		DOZE_AUTO "sleep";

		ALPM_AUTO "sleep";

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
