#!/bin/sh
# SL8541E GNSS Boot Logger Setup (Standalone)

# Root Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] You must run this as root!"
    exit 1
fi

mount -o remount,rw /vendor 2>/dev/null

# 1. The Script
cat << 'EOF' > /vendor/bin/boot_logger.sh
#!/system/bin/sh
# Wait for system to settle
sleep 15
# Start logging all buffers to file
# -b all: all buffers (main, system, radio, etc)
# -n 5: keep 5 rotated files
# -r 2048: rotate at 2MB each
logcat -b all -f /data/local/tmp/boot_log.txt -n 5 -r 2048 &
EOF
chmod 755 /vendor/bin/boot_logger.sh

# 2. The Init Service
cat << 'EOF' > /vendor/etc/init/boot_logger.rc
service boot_logger /system/bin/sh /vendor/bin/boot_logger.sh
    class core
    user root
    group root system
    oneshot
    seclabel u:r:su:s0
EOF
chmod 644 /vendor/etc/init/boot_logger.rc

echo "Boot logger deployed. Log will be at /data/local/tmp/boot_log.txt"
