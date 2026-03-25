#!/usr/bin/env bash

set -euo pipefail

REMOTE_FILE="/data/misc/wifi/WifiConfigStore.xml"
OUT_DIR="./wifi_config_dumps"

mkdir -p "$OUT_DIR"

echo "[*] Detecting connected devices..."
mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')

if [ "${#DEVICES[@]}" -eq 0 ]; then
    echo "[!] No devices connected"
    exit 1
fi

echo "[*] Available devices:"
for i in "${!DEVICES[@]}"; do
    MODEL="$(adb -s "${DEVICES[$i]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    echo "  [$i] ${DEVICES[$i]} ${MODEL:+($MODEL)}"
done

if [ "${#DEVICES[@]}" -eq 1 ]; then
    SERIAL="${DEVICES[0]}"
else
    read -rp "Select device index: " INDEX
    if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ "$INDEX" -ge "${#DEVICES[@]}" ]; then
        echo "[!] Invalid selection"
        exit 1
    fi
    SERIAL="${DEVICES[$INDEX]}"
fi

ADB=(adb -s "$SERIAL")

echo "[*] Using device: $SERIAL"

"${ADB[@]}" root >/dev/null 2>&1 || true
sleep 1

IMEI="$("${ADB[@]}" shell service call iphonesubinfo 1 2>/dev/null \
    | tr -d '\r' \
    | tr "'" '\n' \
    | grep -E '[0-9]\.[0-9]' \
    | tr -cd '0-9' || true)"

[ -z "$IMEI" ] && IMEI="unknownimei"

NOW="$(date '+%Y%m%d_%H%M%S')"
LOCAL_FILE="${OUT_DIR}/${NOW}_${IMEI}_WifiConfigStore.xml"

echo "[*] Pulling $REMOTE_FILE ..."
"${ADB[@]}" pull "$REMOTE_FILE" "$LOCAL_FILE" >/dev/null

echo "[*] Saved to: $LOCAL_FILE"
