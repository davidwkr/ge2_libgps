#!/usr/bin/env bash
# SL8541E GNSS Configuration Audit Tool
# Version 1.0

set -euo pipefail

echo "--- GNSS Configuration Audit Tool ---"

# 1. Device Selection
mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')

if [ "${#DEVICES[@]}" -eq 0 ]; then
    echo "[!] No devices connected via ADB"
    exit 1
fi

if [ "${#DEVICES[@]}" -eq 1 ]; then
    SERIAL="${DEVICES[0]}"
    echo "[*] Using device: $SERIAL"
else
    echo "[*] Multiple devices found:"
    for i in "${!DEVICES[@]}"; do
        echo "    [$i] ${DEVICES[$i]}"
    done
    read -p "Select device index: " INDEX
    SERIAL="${DEVICES[$INDEX]}"
fi

ADB="adb -s $SERIAL"

# 2. Basic Info
echo -e "\n[ SYSTEM INFO ]"
DATE=$($ADB shell date)
echo "Date/Time:      $DATE"
OPERATOR=$($ADB shell getprop gsm.sim.operator.numeric | tr -d '\r')
echo "SIM Operator:   ${OPERATOR:-[Not Detected]}"

# 3. SUPL Configuration
echo -en "\n[ SUPL CONFIGURATION ]\n"
# Check both paths, prioritizing the /data override if it exists
for P in "/data/gnss/supl/supl.xml" "/vendor/etc/supl.xml"; do
    SUPL_XML=$($ADB shell "cat '$P' 2>/dev/null" || echo "")
    if [ -n "$SUPL_XML" ]; then
        echo "Source:         $P"
        SERVER=$(echo "$SUPL_XML" | python3 -c "import sys, re; m=re.search(r'NAME=\"SERVER-ADDRESS\".*?VALUE=\"(.*?)\"', sys.stdin.read()); print(m.group(1)) if m else print('')")
        PORT=$(echo "$SUPL_XML" | python3 -c "import sys, re; m=re.search(r'NAME=\"SERVER-PORT\".*?VALUE=\"(.*?)\"', sys.stdin.read()); print(m.group(1)) if m else print('')")
        IFACE=$(echo "$SUPL_XML" | python3 -c "import sys, re; m=re.search(r'INTERFACE=\"(.*?)\"', sys.stdin.read()); print(m.group(1)) if m else print('')")
        CP=$(echo "$SUPL_XML" | python3 -c "import sys, re; m=re.search(r'NAME=\"CONTROL-PLANE\".*?VALUE=\"(.*?)\"', sys.stdin.read()); print(m.group(1)) if m else print('')")
        
        echo "Server:         ${SERVER:-[None]}"
        echo "Port:           ${PORT:-[None]}"
        IS_WIFI="FALSE"; [ "$IFACE" = "any" ] && IS_WIFI="TRUE"
        echo "Interface:      ${IFACE:-[None]} $([ "$IS_WIFI" = "TRUE" ] && echo "(WiFi-Friendly)" || echo "(LTE-Only)")"
        echo "Control Plane:  ${CP:-[None]}"
        break
    fi
done
[ -z "$SUPL_XML" ] && echo "Status:         [MISSING SUPL FILES]"

# 4. Engine Configuration (Lower level)
echo -e "\n[ ENGINE CONFIGURATION (/vendor/etc/config.xml) ]"
CONFIG_XML=$($ADB shell "cat /vendor/etc/config.xml 2>/dev/null" || echo "")
if [ -z "$CONFIG_XML" ]; then
    echo "Status:         [MISSING]"
else
    # Use python to safely extract property values
    CMCC=$(echo "$CONFIG_XML" | python3 -c "import sys, re; m=re.search(r'NAME=\"CMCC-ENABLE\".*?VALUE=\"(.*?)\"', sys.stdin.read()); print(m.group(1)) if m else print('')")
    CP_EN=$(echo "$CONFIG_XML" | python3 -c "import sys, re; m=re.search(r'NAME=\"CP-ENABLE\".*?VALUE=\"(.*?)\"', sys.stdin.read()); print(m.group(1)) if m else print('')")
    
    echo "CMCC-Mode:      ${CMCC:-[None]} $([ "$CMCC" = "TRUE" ] && echo "(Carrier Proprietary)" || echo "(A-GNSS Standard)")"
    echo "CP-Hardware:    ${CP_EN:-[None]} $([ "$CP_EN" = "TRUE" ] && echo "(Enabled)" || echo "(Disabled/Missing)")"
fi

# 5. On-Device Fix History
echo -e "\n[ ON-DEVICE FIX HISTORY (/data/gnss/fix_history.log) ]"
HISTORY=$($ADB shell "tail -n 3 /data/gnss/fix_history.log 2>/dev/null" | tr -d '\r' || echo "")
if [ -z "$HISTORY" ]; then
    echo "Status:         [NO HISTORY LOG FOUND]"
else
    echo "$HISTORY"
fi

# 6. Logging Status
echo -e "\n[ LOGGING STATUS ]"
IS_LOGGING=$($ADB shell "ls /vendor/bin/boot_logger.sh 2>/dev/null" | tr -d '\r' || echo "FALSE")
if [[ "$IS_LOGGING" == *"/vendor/bin/boot_logger.sh"* ]]; then
    echo "Boot Logger:    [ENABLED]"
else
    echo "Boot Logger:    [DISABLED]"
fi

echo -e "\n--- Audit Complete ---"
