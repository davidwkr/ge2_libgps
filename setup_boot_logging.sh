#!/bin/sh
# SL8541E GNSS Boot Logger SETUP
# Note: Use deploy_fix.sh for automated deployment.

# 1. The Script
SCRIPT_CONTENT='#!/system/bin/sh
sleep 15
logcat -b all -f /data/local/tmp/boot_log.txt -n 5 -r 2048 &
'

# 2. The Init Service
RC_CONTENT='service boot_logger /system/bin/sh /vendor/bin/boot_logger.sh
    class core
    user root
    group root system
    oneshot
    seclabel u:r:su:s0
'

# Manual Deployment Instructions:
# adb shell "mount -o remount,rw /vendor"
# adb shell "echo \"$SCRIPT_CONTENT\" > /vendor/bin/boot_logger.sh"
# adb shell "chmod 755 /vendor/bin/boot_logger.sh"
# adb shell "echo \"$RC_CONTENT\" > /vendor/etc/init/boot_logger.rc"
# adb shell "chmod 644 /vendor/etc/init/boot_logger.rc"

echo "Boot logger scripts generated. Use deploy_fix.sh to push to a device."
