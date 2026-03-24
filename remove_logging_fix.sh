#!/bin/sh
# SL8541E GNSS Boot Logger Removal (Standalone)

# Root Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] You must run this as root!"
    exit 1
fi

mount -o remount,rw /vendor 2>/dev/null

echo "[STEP] Removing boot logger files..."
rm /vendor/bin/boot_logger.sh 2>/dev/null
rm /vendor/etc/init/boot_logger.rc 2>/dev/null
rm /data/local/tmp/boot_log.txt* 2>/dev/null

echo "Boot logger removed."
