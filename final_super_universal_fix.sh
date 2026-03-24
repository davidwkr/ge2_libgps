#!/bin/sh
# SL8541E GNSS THE ULTIMATE FIX SCRIPT (Master Framework Sync)
# With full validation checks, seth_lte0 interface, and gps.conf forced override

echo "--- Starting GNSS Fix with Master Framework Sync ---"

# 1. Validation: Root Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] You must run this as root (su)!"
    exit 1
fi

# 2. Validation: Mount Check
echo "[STEP] Remounting filesystems..."
mount -o remount,rw /vendor 2>/dev/null
mount -o remount,rw /system 2>/dev/null
mount -o remount,rw /data 2>/dev/null

if ! touch /vendor/.test_write 2>/dev/null; then
    echo "[ERROR] Failed to make /vendor writable. Fix aborted."
    exit 1
else
    rm /vendor/.test_write
    echo "[OK] Filesystems are writable."
fi

# 2b. Date Helper: System clock fix for SL8541E (reboot reset workaround)
YEAR=$(date +%Y)
if [ "$YEAR" -lt 2024 ]; then
    echo "[STEP] System clock is behind (Detected: $YEAR). Forcing sync to March 2026..."
    date 032400002026.00 >/dev/null 2>&1
    echo "[OK] Date adjusted to: $(date)"
fi

# 3. Data Gathering: Dynamic Argentine Detection
NUMERIC=$(getprop gsm.sim.operator.numeric | cut -d, -f1 | tr -dc '0-9')
[ -z "$NUMERIC" ] && [ -n "$1" ] && NUMERIC="$1" 

if [ ${#NUMERIC} -lt 5 ]; then
    echo "[WARNING] Could not detect valid MCC/MNC from SIM (got: '$NUMERIC')."
    echo "Falling back to Argentina Universal (722.010) Default..."
    MCC="722"
    MNC="010"
else
    MCC=$(echo "$NUMERIC" | cut -c 1-3)
    MNC=$(echo "$NUMERIC" | cut -c 4-6)
    echo "[OK] Detected Carrier SIM: MCC=$MCC, MNC=$MNC"
fi

# 4. Define the "Deep Vendor Dual-Block" Configuration
SUPL_CONTENT="<?xml version=\"1.0\" encoding=\"utf-8\"?>
<SPRDGNSS>
    <COMM>
        <!-- Standard SUPL Block -->
        <PROTOCOL NAME=\"RX_SUPL_PROTOCOL\" TYPE=\"SUPL\" INTERFACE=\"seth_lte0\">
          <PROPERTY NAME=\"ENABLE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"SERVER-ADDRESS\" VALUE=\"172.217.192.192\"/>
          <PROPERTY NAME=\"SERVER-PORT\" VALUE=\"7275\"/>
          <PROPERTY NAME=\"HLP-ENABLE\" VALUE=\"FALSE\"/>
          <PROPERTY NAME=\"MPM\" VALUE=\"LOCATION\"/>
          <PROPERTY NAME=\"SUPL-MODE\" VALUE=\"msb\"/>
          <PROPERTY NAME=\"CELL-ID-GSM-MCC\" VALUE=\"$MCC\"/>
          <PROPERTY NAME=\"CELL-ID-GSM-MNC\" VALUE=\"$MNC\"/>
          <PROPERTY NAME=\"CONTROL-PLANE\" VALUE=\"FALSE\"/>
        </PROTOCOL>
        <!-- Dedicated Control Plane Block (For Personal Argentina) -->
        <PROTOCOL NAME=\"RX_CP_PROTOCOL\" TYPE=\"CP\" INTERFACE=\"DUMMY2\">
          <PROPERTY NAME=\"ENABLE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"CONTROL-PLANE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"MPM\" VALUE=\"LOCATION\"/>
        </PROTOCOL>
    </COMM>
</SPRDGNSS>"

# 5. Define the Master Framework Sync (gps.conf)
GPS_CONF_CONTENT="SUPL_HOST=NONE
SUPL_PORT=0
SUPL_MODE=0
SUPL_VER=0x20000
NTP_SERVER=ar.pool.ntp.org
XTRA_SERVER_1=http://xtrapath4.izatcloud.net/xtra2.bin
INTERMEDIATE_POS=0
ACCURACY_THRES=0
ENABLE_WIFI_定位=0
CAPABILITIES=0x37
"

# 6. Overwrite SUPL XMLs
PATHS="/vendor/etc/supl.xml /data/gnss/supl/supl.xml"
for TARGET in $PATHS; do
    echo "[STEP] Updating $TARGET..."
    [ -f "$TARGET" ] && [ ! -f "${TARGET}.bak" ] && cp "$TARGET" "${TARGET}.bak"
    echo "$SUPL_CONTENT" > "$TARGET"
done

# 7. Overwrite/Create gps.conf
CONF_PATHS="/vendor/etc/gps.conf /system/etc/gps.conf"
for CONF in $CONF_PATHS; do
    echo "[STEP] Syncing $CONF..."
    [ -f "$CONF" ] && [ ! -f "${CONF}.bak" ] && cp "$CONF" "${CONF}.bak"
    echo "$GPS_CONF_CONTENT" > "$CONF"
done

# 8. Flush Cache & Deep Clean
echo "[STEP] Performing deep cleanup of GNSS state..."
rm -rf /data/gnss/lte/* 2>/dev/null
rm -rf /data/gnss/supl/*.xml 2>/dev/null
rm -rf /data/gnss/log/* 2>/dev/null

# 9. SELinux Fix (Self-Healing)
echo "[STEP] Restoring SELinux contexts..."
restorecon -R /vendor/etc/supl.xml 2>/dev/null
restorecon -R /data/gnss/supl/ 2>/dev/null
restorecon -R /vendor/etc/gps.conf 2>/dev/null
restorecon -R /system/etc/gps.conf 2>/dev/null
restorecon -R /vendor/etc/config.xml 2>/dev/null # Added for config.xml

# Log On-Device
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applied UNIVERSAL Fix" >> /data/gnss/fix_history.log

# 10. Deep Vendor Optimization (config.xml)
CONFIG_XML="/vendor/etc/config.xml"
if [ -f "$CONFIG_XML" ]; then
    echo "[STEP] Optimizing $CONFIG_XML for Argentina (Deep CP Enable)..."
    [ ! -f "${CONFIG_XML}.bak" ] && cp "$CONFIG_XML" "${CONFIG_XML}.bak"
    # Disable CMCC but Force CP-ENABLE
    sed -i 's/NAME="CMCC-ENABLE" VALUE="TRUE"/NAME="CMCC-ENABLE" VALUE="FALSE"/g' "$CONFIG_XML"
    # Insert CP-ENABLE if it doesn't exist
    if ! grep -q "CP-ENABLE" "$CONFIG_XML"; then
        sed -i '/<GNSS>/a \        <PROPERTY NAME="CP-ENABLE" VALUE="TRUE"/>' "$CONFIG_XML"
    fi
    echo "[OK] config.xml patched."
fi

echo "--- Aligned. Please REBOOT. ---"
