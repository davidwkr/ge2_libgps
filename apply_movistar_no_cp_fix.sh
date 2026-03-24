#!/bin/sh
# SL8541E GNSS Standalone Fix - MOVISTAR (No Control Plane)
# Similar to Claro's fix, intended for Movistar users where CP causes issues.

echo "--- Starting standalone GNSS Fix (Movistar No-CP) ---"

# Root Check
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] You must run this as root!"
    exit 1
fi

# Remount
mount -o remount,rw /vendor 2>/dev/null
mount -o remount,rw /data 2>/dev/null

# Embed SUPL XML
SUPL_CONTENT='<?xml version="1.0" encoding="utf-8"?>
<SPRDGNSS>
    <COMM>
        <PROTOCOL NAME="RX_SUPL_PROTOCOL" TYPE="SUPL" INTERFACE="seth_lte0">
          <PROPERTY NAME="ENABLE" VALUE="TRUE"/>
          <PROPERTY NAME="SERVER-ADDRESS" VALUE="172.217.192.192"/>
          <PROPERTY NAME="SERVER-PORT" VALUE="7275"/>
          <PROPERTY NAME="HLP-ENABLE" VALUE="FALSE"/>
          <PROPERTY NAME="SUPL-MODE" VALUE="msb"/>
          <PROPERTY NAME="VERSION" VALUE="SUPL_15.5.2"/>
          <PROPERTY NAME="SUPL-VERSION" VALUE="v2.0.0"/>
          <PROPERTY NAME="TLS-ENABLE" VALUE="TRUE"/>
          <PROPERTY NAME="CER-VERIFY" VALUE="FALSE"/>
          <PROPERTY NAME="SUPL-CER" VALUE="/data/gnss/supl/suplrootca.pem"/>
          <PROPERTY NAME="SUPLLOG-SAVE" VALUE="TRUE"/>
          <PROPERTY NAME="NI-ENABLE" VALUE="TRUE"/>
          <PROPERTY NAME="NI-TEST" VALUE="NOTIFIONLY"/>
          <PROPERTY NAME="CONTROL-PLANE" VALUE="FALSE"/>
          <PROPERTY NAME="NOTIFY-TIMEOUT" VALUE="8"/>
          <PROPERTY NAME="VERIFY-TIMEOUT" VALUE="8"/>
        </PROTOCOL>
    </COMM>
</SPRDGNSS>'

# Embed Config XML
CONFIG_CONTENT='<?xml version="1.0" encoding="utf-8"?>
<GNSS>
        <PROPERTY NAME="CHIP-MODULE" VALUE="GREENEYE2"/>
        <PROPERTY NAME="GPS-IMG-MODE" VALUE="GNSSMODEM"/>
        <PROPERTY NAME="GE2-VERSION" VALUE=""/>
        <PROPERTY NAME="SPREADORBIT-ENABLE" VALUE="TRUE"/>
        <PROPERTY NAME="CP-MODE" VALUE="101"/>
        <PROPERTY NAME="CHIP-ID" VALUE="SP12"/>
        <PROPERTY NAME="OUTPUT-PROTOCOL" VALUE="0011"/>
        <PROPERTY NAME="LOG-ENABLE" VALUE="FALSE"/>
        <PROPERTY NAME="UART-NAME" VALUE="/dev/ttyS3"/>
        <PROPERTY NAME="UART-SPEED" VALUE="3000000"/>
        <PROPERTY NAME="STTY-NAME" VALUE="/dev/sttygnss0"/>
        <PROPERTY NAME="DEBUG-ENABLE" VALUE="TRUE"/>
        <PROPERTY NAME="POST-ENABLE" VALUE="FALSE"/>
        <PROPERTY NAME="APWDG-ENABLE" VALUE="TRUE"/>
        <PROPERTY NAME="REALEPH-ENABLE" VALUE="FALSE"/>
        <PROPERTY NAME="SLEEP-ENABLE" VALUE="TRUE"/>
        <PROPERTY NAME="SLEEP-TIMER" VALUE="300"/>
        <PROPERTY NAME="STOP-TIMER" VALUE="1"/>
        <PROPERTY NAME="CMCC-ENABLE" VALUE="TRUE"/>
        <PROPERTY NAME="TSX-ENABLE" VALUE="FALSE"/>
        <PROPERTY NAME="RF-TOOL" VALUE="FALSE"/>
        <PROPERTY NAME="SUPL-PATH" VALUE="/vendor/etc/supl.xml"/>
        <PROPERTY NAME="NOKIA-EE" VALUE="FALSE"/>
        <PROPERTY NAME="FLOAT-CN0" VALUE="FALSE"/>
        <PROPERTY NAME="BASEBAND-MODE" VALUE="FALSE"/>
        <PROPERTY NAME="MEASURE-REPORT" VALUE="TRUE"/>
        <PROPERTY NAME="PRODUCT_PLATFORM" VALUE="0"/>
</GNSS>'

# Overwrite Vendor Files
echo "[STEP] Syncing /vendor/etc/supl.xml..."
echo "$SUPL_CONTENT" > /vendor/etc/supl.xml
echo "[STEP] Syncing /vendor/etc/config.xml..."
echo "$CONFIG_CONTENT" > /vendor/etc/config.xml

# Flush GNSS State
rm -rf /data/gnss/lte/* 2>/dev/null
rm -rf /data/gnss/supl/*.xml 2>/dev/null
rm -rf /data/gnss/log/* 2>/dev/null

# Restore Contexts
restorecon -R /vendor/etc/supl.xml 2>/dev/null
restorecon -R /vendor/etc/config.xml 2>/dev/null

echo "--- Fix Applied. Please REBOOT. ---"
