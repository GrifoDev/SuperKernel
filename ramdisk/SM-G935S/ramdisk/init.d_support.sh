#!/system/bin/sh

on property:sys.boot_completed=1
    start sysinit
    
service sysinit /sbin/sysinit.sh
    oneshot
    class late_start
    user root
    group root
    disabled
