# --- Boot Logger SETUP ---

# 1. The Script (/vendor/bin/boot_logger.sh)
SCRIPT_CONTENT='#!/system/bin/sh
# Wait for system to settle
sleep 15
# Start logging all buffers to file
# -b all: all buffers (main, system, radio, etc)
# -n 5: keep 5 rotated files
# -r 2048: rotate at 2MB each
logcat -b all -f /data/local/tmp/boot_log.txt -n 5 -r 2048 &
'

# 2. The Init Service (/vendor/etc/init/boot_logger.rc)
RC_CONTENT='service boot_logger /system/bin/sh /vendor/bin/boot_logger.sh
    class core
    user root
    group root system
    oneshot
    seclabel u:r:su:s0
'

# 3. Deployment via ADB
adb -s 60023709384294 shell "mount -o remount,rw /vendor"
adb -s 60023709384294 shell "echo \"$SCRIPT_CONTENT\" > /vendor/bin/boot_logger.sh"
adb -s 60023709384294 shell "chmod 755 /vendor/bin/boot_logger.sh"
adb -s 60023709384294 shell "echo \"$RC_CONTENT\" > /vendor/etc/init/boot_logger.rc"
adb -s 60023709384294 shell "chmod 644 /vendor/etc/init/boot_logger.rc"

echo "Boot logger deployed. Log will be at /data/local/tmp/boot_log.txt"
