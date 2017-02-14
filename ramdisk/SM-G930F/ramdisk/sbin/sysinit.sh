#!/system/bin/sh

mount -o remount,rw /;
mount -o rw,remount /system

/sbin/resetprop -v -n ro.boot.warranty_bit 0
/sbin/resetprop -v -n ro.warranty_bit 0

# init.d support
if [ ! -e /system/etc/init.d ]; then
   mkdir /system/etc/init.d
   chown -R root.root /system/etc/init.d
   chmod -R 755 /system/etc/init.d
fi

# start init.d
for FILE in /system/etc/init.d/*; do
   sh $FILE >/dev/null
done;

