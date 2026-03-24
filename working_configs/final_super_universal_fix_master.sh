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

# 3. Data Gathering: Carrier Info
NUMERIC=$(getprop gsm.sim.operator.numeric | cut -d, -f1 | tr -dc '0-9')
[ -z "$NUMERIC" ] && [ -n "$1" ] && NUMERIC="$1" 

if [ ${#NUMERIC} -lt 5 ]; then
    echo "[WARNING] Could not detect valid MCC/MNC from SIM (got: '$NUMERIC')."
    echo "Falling back to Argentina Universal (722) Default..."
    MCC="722"
    MNC="000"
else
    MCC=$(echo "$NUMERIC" | cut -c 1-3)
    MNC=$(echo "$NUMERIC" | cut -c 4-6)
    echo "[OK] Detected Carrier: MCC=$MCC, MNC=$MNC"
fi

# 3b. Multi-Carrier orientation and logging
if [ "$MCC" = "722" ]; then
    echo "[INFO] Carrier-Agnostic mode. Configuration will work for both Movistar and Claro."
fi

# 4. Define the SUPL Configuration (Aligned with Personal Blueprint but Direct IP)
SUPL_CONTENT="<?xml version=\"1.0\" encoding=\"utf-8\"?>
<SPRDGNSS>
    <COMM>
        <PROTOCOL NAME=\"RX_SUPL_PROTOCOL\" TYPE=\"SUPL\" INTERFACE=\"seth_lte0\">
          <PROPERTY NAME=\"ENABLE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"SERVER-ADDRESS\" VALUE=\"172.217.192.192\"/>
          <PROPERTY NAME=\"SERVER-PORT\" VALUE=\"7275\"/>
          <PROPERTY NAME=\"HLP-ENABLE\" VALUE=\"FALSE\"/>
          <PROPERTY NAME=\"SUPL-MODE\" VALUE=\"msb\"/>
          <PROPERTY NAME=\"VERSION\" VALUE=\"SUPL_15.5.2\"/>
          <PROPERTY NAME=\"SUPL-VERSION\" VALUE=\"v2.0.0\"/>
          <PROPERTY NAME=\"CELL-ID-GSM-MCC\" VALUE=\"$MCC\"/>
          <PROPERTY NAME=\"CELL-ID-GSM-MNC\" VALUE=\"$MNC\"/>
          <PROPERTY NAME=\"TLS-ENABLE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"CER-VERIFY\" VALUE=\"FALSE\"/>
          <PROPERTY NAME=\"SUPL-CER\" VALUE=\"/data/gnss/supl/suplrootca.pem\"/>
          <PROPERTY NAME=\"SUPLLOG-SAVE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"NI-ENABLE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"NI-TEST\" VALUE=\"NOTIFIONLY\"/>
          <PROPERTY NAME=\"CONTROL-PLANE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"NOTIFY-TIMEOUT\" VALUE=\"8\"/>
          <PROPERTY NAME=\"VERIFY-TIMEOUT\" VALUE=\"8\"/>
        </PROTOCOL>
    </COMM>
</SPRDGNSS>"

# 5. Define the Master Framework Sync (gps.conf)
GPS_CONF_CONTENT="SUPL_HOST=172.217.192.192
SUPL_PORT=7275
SUPL_MODE=1
SUPL_VER=0x20000
NTP_SERVER=ar.pool.ntp.org
XTRA_SERVER_1=http://xtrapath4.izatcloud.net/xtra2.bin
INTERMEDIATE_POS=0
ACCURACY_THRES=0
ENABLE_WIFI_定位=0
"

# 6. Overwrite SUPL XMLs
PATHS="/vendor/etc/supl.xml /data/gnss/supl/supl.xml"
for TARGET in $PATHS; do
    echo "[STEP] Updating $TARGET..."
    [ -f "$TARGET" ] && [ ! -f "${TARGET}.bak" ] && cp "$TARGET" "${TARGET}.bak"
    echo "$SUPL_CONTENT" > "$TARGET"
    if grep -q "172.217.192.192" "$TARGET"; then
        echo "[OK] $TARGET updated."
    fi
done

# 7. Overwrite/Create gps.conf
CONF_PATHS="/vendor/etc/gps.conf /system/etc/gps.conf"
for CONF in $CONF_PATHS; do
    echo "[STEP] Syncing $CONF..."
    [ -f "$CONF" ] && [ ! -f "${CONF}.bak" ] && cp "$CONF" "${CONF}.bak"
    echo "$GPS_CONF_CONTENT" > "$CONF"
    echo "[OK] $CONF synced with MSB."
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

# 10. Update config.xml (Carrier Specific Optimization)
CONFIG_XML="/vendor/etc/config.xml"
if [ -f "$CONFIG_XML" ]; then
    echo "[STEP] Optimizing $CONFIG_XML for Argentina (Disabling CMCC Mode)..."
    [ ! -f "${CONFIG_XML}.bak" ] && cp "$CONFIG_XML" "${CONFIG_XML}.bak"
    sed -i 's/NAME="CMCC-ENABLE" VALUE="TRUE"/NAME="CMCC-ENABLE" VALUE="FALSE"/g' "$CONFIG_XML"
    echo "[OK] CMCC-ENABLE set to FALSE in config.xml."
fi

echo "--- Aligned. Please REBOOT. ---"
