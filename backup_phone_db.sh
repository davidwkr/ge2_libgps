#!/usr/bin/env bash
# restore:
# tar -xzf backup.tar.gz
# adb push payload/* /data/data/com.urbetrack.sweeptracker/databases/

set -euo pipefail

PACKAGE="com.urbetrack.sweeptracker"
REMOTE_DB_DIR="/data/data/${PACKAGE}/databases"
REMOTE_DB_BASE="locations.db"
REMOTE_TMP_DIR="/data/local/tmp"
REMOTE_OUT_DIR="/sdcard/backup_locations"
LOCAL_OUT_DIR="./phone_db_backups"

mkdir -p "$LOCAL_OUT_DIR"

echo "[*] Detecting connected devices..."

mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')

if [ "${#DEVICES[@]}" -eq 0 ]; then
    echo "[!] No devices connected"
    exit 1
fi

echo "[*] Available devices:"
for i in "${!DEVICES[@]}"; do
    echo "  [$i] ${DEVICES[$i]}"
done

if [ "${#DEVICES[@]}" -eq 1 ]; then
    SELECTED_DEVICE="${DEVICES[0]}"
    echo "[*] Only one device found, using: $SELECTED_DEVICE"
else
    read -rp "Select device index: " INDEX

    if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ "$INDEX" -ge "${#DEVICES[@]}" ]; then
        echo "[!] Invalid selection"
        exit 1
    fi

    SELECTED_DEVICE="${DEVICES[$INDEX]}"
fi

echo "[*] Using device: $SELECTED_DEVICE"

ADB="adb -s $SELECTED_DEVICE"

echo "[*] Creating backup on device..."

REMOTE_FILE="$(
$ADB shell <<'EOF' | tr -d '\r' | tail -n 1
set -eu

PACKAGE="com.urbetrack.sweeptracker"
REMOTE_DB_DIR="/data/data/${PACKAGE}/databases"
REMOTE_DB_BASE="locations.db"
REMOTE_TMP_DIR="/data/local/tmp"
REMOTE_OUT_DIR="/sdcard/backup_locations"
NOW="$(date '+%Y%m%d_%H%M%S')"

mkdir -p "$REMOTE_OUT_DIR"

get_imei() {
    service call iphonesubinfo 1 2>/dev/null \
    | tr "'" '\n' \
    | grep -E '[0-9]\.[0-9]' \
    | tr -cd '0-9'
}

IMEI="$(get_imei || true)"
[ -z "$IMEI" ] && IMEI="unknownimei"

WORK_DIR="${REMOTE_TMP_DIR}/locations_backup_${NOW}_$$"
PAYLOAD_DIR="${WORK_DIR}/payload"
ARCHIVE_NAME="${NOW}_${IMEI}_locationsdb.tar.gz"
ARCHIVE_PATH="${REMOTE_OUT_DIR}/${ARCHIVE_NAME}"

mkdir -p "$PAYLOAD_DIR"

cp "${REMOTE_DB_DIR}/${REMOTE_DB_BASE}" "${PAYLOAD_DIR}/locations.db"

[ -f "${REMOTE_DB_DIR}/${REMOTE_DB_BASE}-wal" ] && cp "${REMOTE_DB_DIR}/${REMOTE_DB_BASE}-wal" "${PAYLOAD_DIR}/locations.db-wal"
[ -f "${REMOTE_DB_DIR}/${REMOTE_DB_BASE}-shm" ] && cp "${REMOTE_DB_DIR}/${REMOTE_DB_BASE}-shm" "${PAYLOAD_DIR}/locations.db-shm"

tar -czf "$ARCHIVE_PATH" -C "$WORK_DIR" payload

rm -rf "$WORK_DIR"

echo "$ARCHIVE_PATH"
EOF
)"

if [ -z "$REMOTE_FILE" ]; then
    echo "[!] Failed to create remote backup file"
    exit 1
fi

echo "[*] Remote backup created: $REMOTE_FILE"

BASENAME="$(basename "$REMOTE_FILE")"

echo "[*] Pulling backup to host..."
$ADB pull "$REMOTE_FILE" "${LOCAL_OUT_DIR}/${BASENAME}"

echo "[*] Done"
echo "    Device: $SELECTED_DEVICE"
echo "    Local:  ${LOCAL_OUT_DIR}/${BASENAME}"
echo "    Remote: ${REMOTE_FILE}"