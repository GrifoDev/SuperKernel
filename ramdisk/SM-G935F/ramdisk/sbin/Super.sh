#!/system/bin/sh

BB=/system/xbin/busybox;

# Mount root as RW to apply tweaks and settings
if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;
if [ "$($BB mount | grep system | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /system;
fi;


# Setup for Cron Task
if [ ! -d /data/.Super ]; then
	$BB mkdir -p /data/.Super
	$BB chmod -R 0777 /.Super/
fi;
# Copy Cron files
$BB cp -a /res/crontab/ /data/


# Set correct r/w permissions for LMK parameters
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/minfree;

# Set stock freqs as default freqs on boot
echo 1586000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 2496000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq

# Disable rotational storage for all blocks
# We need faster I/O so do not try to force moving to other CPU cores (dorimanx)
for i in /sys/block/*/queue; do
	echo "0" > "$i"/rotational;
	echo "2" > "$i"/rq_affinity;
done;


# Allow untrusted apps to read from debugfs (mitigate SELinux denials)
if [ -e /su/lib/libsupol.so ]; then
/system/xbin/supolicy --live \
	"allow untrusted_app debugfs file { open read getattr }" \
	"allow untrusted_app sysfs_lowmemorykiller file { open read getattr }" \
	"allow untrusted_app sysfs_devices_system_iosched file { open read getattr }" \
	"allow untrusted_app persist_file dir { open read getattr }" \
	"allow debuggerd gpu_device chr_file { open read getattr }" \
	"allow netd netd capability fsetid" \
	"allow netd { hostapd dnsmasq } process fork" \
	"allow { system_app shell } dalvikcache_data_file file write" \
	"allow { zygote mediaserver bootanim appdomain }  theme_data_file dir { search r_file_perms r_dir_perms }" \
	"allow { zygote mediaserver bootanim appdomain }  theme_data_file file { r_file_perms r_dir_perms }" \
	"allow system_server { rootfs resourcecache_data_file } dir { open read write getattr add_name setattr create remove_name rmdir unlink link }" \
	"allow system_server resourcecache_data_file file { open read write getattr add_name setattr create remove_name unlink link }" \
	"allow system_server dex2oat_exec file rx_file_perms" \
	"allow mediaserver mediaserver_tmpfs file execute" \
	"allow drmserver theme_data_file file r_file_perms" \
	"allow zygote system_file file write" \
	"allow atfwd property_socket sock_file write" \
	"allow untrusted_app sysfs_display file { open read write getattr add_name setattr remove_name }" \
	"allow debuggerd app_data_file dir search" \
	"allow sensors diag_device chr_file { read write open ioctl }" \
	"allow sensors sensors capability net_raw" \
	"allow init kernel security setenforce" \
	"allow netmgrd netmgrd netlink_xfrm_socket nlmsg_write" \
	"allow netmgrd netmgrd socket { read write open ioctl }"
fi;

if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;

# Synapse
$BB chmod -R 755 /res/*
$BB ln -fs /res/synapse/uci /sbin/uci
/sbin/uci


if [ "$($BB mount | grep rootfs | cut -c 26-27 | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /;
fi;
if [ "$($BB mount | grep system | grep -c ro)" -eq "1" ]; then
	$BB mount -o remount,rw /system;
fi;

# Init.d
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/;
	chown -R root.root /system/etc/init.d;
	chmod 777 /system/etc/init.d/;
	chmod 777 /system/etc/init.d/*;
fi;
$BB run-parts /system/etc/init.d

# Run Cortexbrain script
# Cortex parent should be ROOT/INIT and not Synapse
cortexbrain_background_process=$(cat /res/synapse/Super/cortexbrain_background_process);
if [ "$cortexbrain_background_process" == "1" ]; then
	sleep 30
	$BB nohup $BB sh /sbin/cortexbrain-tune.sh > /dev/null 2>&1 &
fi;


# Start CROND by tree root, so it's will not be terminated.
cron_master=$(cat /res/synapse/Super/cron_master);
if [ "$cron_master" == "1" ]; then
	$BB nohup $BB sh /res/crontab_service/service.sh 2> /dev/null;
fi;


# Kernel custom test
if [ -e /data/.Super_test.log ]; then
	rm /data/.Super_test.log
fi;
echo  Kernel script is working !!! >> /data/.Super_test.log
echo "excecuted on $(date +"%d-%m-%Y %r" )" >> /data/.Super_test.log

fi;


$BB mount -t rootfs -o remount,ro rootfs
$BB mount -o remount,ro /system
$BB mount -o remount,rw /data
