#!/bin/bash
# SL8541E GNSS Interactive Deployment Tool

echo "------------------------------------------------"
echo "  GREENEYE2 GNSS FIX DEPLOYMENT TOOL (Interactive)"
echo "------------------------------------------------"

# Check for ADB
if ! command -v adb &> /dev/null; then
    echo "[ERROR] adb could not be found. Please install platform-tools."
    exit 1
fi

# 1. Gather devices
echo "Scanning for ADB devices..."
RAW_DEVICES=$(adb devices | grep -v "List" | grep "device" | awk '{print $1}')
DEVICES=($RAW_DEVICES)

if [ ${#DEVICES[@]} -eq 0 ]; then
    echo "[ERROR] No devices found. Make sure ADB is enabled and authorized."
    exit 1
fi

echo "Connected Devices:"
for i in "${!DEVICES[@]}"; do
    SERIAL="${DEVICES[$i]}"
    # Get MCC/MNC from Sim 1 or 2
    MCCMNC=$(adb -s "$SERIAL" shell getprop gsm.sim.operator.numeric | cut -d, -f1 | tr -dc '0-9')
    PRODUCT=$(adb -s "$SERIAL" shell getprop ro.product.model)
    [ -z "$MCCMNC" ] && MCCMNC="[Offline/No SIM]"
    
    # Check for on-device history (requires root)
    LAST_FIX=$(adb -s "$SERIAL" shell "[ -f /data/gnss/fix_history.log ] && tail -n 1 /data/gnss/fix_history.log || echo 'No History Found'")
    
    echo "  [$i] $SERIAL - $PRODUCT ($MCCMNC)"
    echo "      Current State: $LAST_FIX"
done

echo ""
read -p "Select device index [0-$(( ${#DEVICES[@]} - 1 ))]: " DEV_IDX

# Validation
TARGET_SERIAL="${DEVICES[$DEV_IDX]}"
if [ -z "$TARGET_SERIAL" ]; then
    echo "[ERROR] Invalid selection."
    exit 1
fi

# Re-fetch metadata for the selected device
TARGET_MODEL=$(adb -s "$TARGET_SERIAL" shell getprop ro.product.model)
TARGET_MCCMNC=$(adb -s "$TARGET_SERIAL" shell getprop gsm.sim.operator.numeric | cut -d, -f1 | tr -dc '0-9')
[ -z "$TARGET_MCCMNC" ] && TARGET_MCCMNC="[Offline/No SIM]"

echo "Targeting Device: $TARGET_SERIAL ($TARGET_MODEL)"
echo ""
echo "Available Configurations:"
echo " [1] Universal Fix (Master Framework Sync - Dynamic MCC/MNC)"
echo " [2] Claro Argentina Fix (Standalone - Pointing to 172.217.192.192)"
echo " [3] Movistar Argentina Fix (Standalone - Pointing to 172.217.192.192 + CP Enable)"
echo " [4] Movistar Argentina (No Control Plane - Standard)"
echo " [5] Movistar Argentina (No Control Plane + WiFi Optimized)"
echo " [6] Revert to Stock Config (Point back to unisoc.supl.qxwz.com)"
echo " [7] ENABLE Persistent GNSS Logging (at boot)"
echo " [8] DISABLE Persistent GNSS Logging"
echo " [Q] Quit"

read -p "Choose your action [1-8/Q]: " CONF_IDX

case $CONF_IDX in
    1) SCRIPT="final_super_universal_fix.sh" ;;
    2) SCRIPT="apply_claro_fix.sh" ;;
    3) SCRIPT="apply_movistar_fix.sh" ;;
    4) SCRIPT="apply_movistar_no_cp_fix.sh" ;;
    5) SCRIPT="apply_movistar_no_cp_wifi_fix.sh" ;;
    6) SCRIPT="revert_to_stock_configs.sh" ;;
    7) SCRIPT="apply_logging_fix.sh" ;;
    8) SCRIPT="remove_logging_fix.sh" ;;
    [qQ]) echo "Exit."; exit 0 ;;
    *) echo "[ERROR] Invalid selection."; exit 1 ;;
esac

# Check script exists
if [ ! -f "$SCRIPT" ]; then
    echo "[ERROR] Script '$SCRIPT' not found in current directory."
    exit 1
fi

echo ""
echo "[STEP 1/3] Pushing $SCRIPT to /data/local/tmp/fix.sh..."
adb -s "$TARGET_SERIAL" push "$SCRIPT" /data/local/tmp/fix.sh

echo "[STEP 2/3] Executing fix script as root..."
adb -s "$TARGET_SERIAL" shell "chmod +x /data/local/tmp/fix.sh && echo 'sh /data/local/tmp/fix.sh' | su"

echo "[STEP 3/3] Deployment finished."
read -p "Reboot device now to apply changes? [Y/n]: " CONF_REBOOT
if [[ "$CONF_REBOOT" =~ ^[Yy]$ ]] || [ -z "$CONF_REBOOT" ]; then
    echo "Rebooting $TARGET_SERIAL..."
    adb -s "$TARGET_SERIAL" reboot
else
    echo "Skipping reboot. Remember to reboot manually."
fi

# Log the deployment
LOG_FILE="deployment_history.log"
DATE_STR=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$DATE_STR] Device:$TARGET_SERIAL | Model:$TARGET_MODEL | Carrier:$TARGET_MCCMNC | Fix:$SCRIPT" >> "$LOG_FILE"

echo ""
echo "------------------------------------------------"
echo "  SUCCESS: Fix deployed to $TARGET_SERIAL."
echo "  Targeting was: $TARGET_MODEL ($TARGET_MCCMNC)"
echo "  History recorded in $LOG_FILE"
echo "  Wait for reboot and check GNSS status."
echo "------------------------------------------------"
