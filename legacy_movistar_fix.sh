#!/bin/bash

# --- Master Mirror Fix (Aligned with Working Device) ---
# Targets 'assist request flag invalid' and 'ephemeris too old' errors.

echo "--- Starting Master Mirror Fix ---"

# 1. Remount for write access
mount -o remount,rw /vendor 2>/dev/null
mount -o remount,rw /data 2>/dev/null
mount -o remount,rw /system 2>/dev/null

# 2. Detect Carrier
NUMERIC=$(getprop gsm.sim.operator.numeric | cut -d, -f1 | tr -dc '0-9')
MCC=$(echo "$NUMERIC" | cut -c 1-3)
MNC=$(echo "$NUMERIC" | cut -c 4-6)

if [ -z "$MCC" ]; then
    MCC="722"
    MNC="07"
fi
echo "[OK] Carrier: MCC=$MCC, MNC=$MNC"

# 3. Define the Master Mirror XML
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
          <PROPERTY NAME=\"CONTROL-PLANE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"SUPLLOG-SAVE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"NI-ENABLE\" VALUE=\"TRUE\"/>
          <PROPERTY NAME=\"NOTIFY-TIMEOUT\" VALUE=\"8\"/>
          <PROPERTY NAME=\"VERIFY-TIMEOUT\" VALUE=\"8\"/>
        </PROTOCOL>
    </COMM>
</SPRDGNSS>"

# 4. Define gps.conf
GPS_CONF="SUPL_HOST=172.217.192.192
SUPL_PORT=7275
SUPL_MODE=1
SUPL_VER=0x20000
NTP_SERVER=ar.pool.ntp.org
XTRA_SERVER_1=http://xtrapath4.izatcloud.net/xtra2.bin
CAPABILITIES=0x37
"

# 5. Apply
echo "[STEP] Applying Master Mirror XML..."
echo "$SUPL_CONTENT" > /vendor/etc/supl.xml
echo "$SUPL_CONTENT" > /data/gnss/supl/supl.xml

echo "[STEP] Syncing gps.conf..."
echo "$GPS_CONF" > /vendor/etc/gps.conf
echo "$GPS_CONF" > /system/etc/gps.conf

echo "[STEP] Resetting LTE/EPH cache and logs..."
rm -rf /data/gnss/lte/*
rm -rf /data/gnss/supl/*.xml
rm -rf /data/gnss/log/*

restorecon -R /vendor/etc/supl.xml 2>/dev/null
restorecon -R /data/gnss/supl/ 2>/dev/null
restorecon -R /vendor/etc/gps.conf 2>/dev/null

echo "--- Master Mirror Applied. Please REBOOT. ---"
