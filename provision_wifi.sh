#!/usr/bin/env bash

set -euo pipefail

SSID='Picun_EXT'
PASSWORD='redondos'

REMOTE_WIFI_XML='/data/misc/wifi/WifiConfigStore.xml'
REMOTE_TMP_XML='/data/local/tmp/WifiConfigStore.xml'
REMOTE_BACKUP_DIR='/data/local/tmp/wifi_config_backups'
LOCAL_WORK_DIR='./wifi_provision_work'

mkdir -p "$LOCAL_WORK_DIR"

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
    echo "[*] Only one device found, using: $SERIAL"
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
echo "[*] Restarting adbd as root..."
"${ADB[@]}" root >/dev/null 2>&1 || true
sleep 2

echo "[*] Waiting for device..."
"${ADB[@]}" wait-for-device

echo "[*] Checking access to $REMOTE_WIFI_XML ..."
if ! "${ADB[@]}" shell "test -f '$REMOTE_WIFI_XML'"; then
    echo "[!] Cannot access $REMOTE_WIFI_XML"
    exit 1
fi

IMEI="$("${ADB[@]}" shell service call iphonesubinfo 1 2>/dev/null \
    | tr -d '\r' \
    | tr "'" '\n' \
    | grep -E '[0-9]\.[0-9]' \
    | tr -cd '0-9' || true)"
[ -z "$IMEI" ] && IMEI="unknownimei"

NOW="$(date '+%Y%m%d_%H%M%S')"
LOCAL_ORIG="${LOCAL_WORK_DIR}/${NOW}_${IMEI}_WifiConfigStore.original.xml"
LOCAL_PATCHED="${LOCAL_WORK_DIR}/${NOW}_${IMEI}_WifiConfigStore.patched.xml"

echo "[*] Disabling Wi-Fi..."
"${ADB[@]}" shell svc wifi disable || true
sleep 3

echo "[*] Backing up remote WifiConfigStore.xml on device..."
"${ADB[@]}" shell "mkdir -p '$REMOTE_BACKUP_DIR' && cp '$REMOTE_WIFI_XML' '$REMOTE_BACKUP_DIR/WifiConfigStore.xml.$NOW.bak'"

echo "[*] Pulling current WifiConfigStore.xml..."
"${ADB[@]}" pull "$REMOTE_WIFI_XML" "$LOCAL_ORIG" >/dev/null

echo "[*] Creating local backup safety copy..."
cp "$LOCAL_ORIG" "${LOCAL_ORIG}.bak"

echo "[*] Checking if SSID already exists in current config..."
if grep -F "<string name=\"SSID\">&quot;${SSID}&quot;</string>" "$LOCAL_ORIG" >/dev/null; then
    echo "[*] SSID already configured -> skipping provisioning"

    echo "[*] Re-enabling Wi-Fi..."
    "${ADB[@]}" shell svc wifi enable || true
    sleep 5

    echo "[*] Current Wi-Fi summary:"
    "${ADB[@]}" shell dumpsys wifi 2>/dev/null | tr -d '\r' | grep -E 'Wi-Fi is|mNetworkInfo|SSID|BSSID|Supplicant state|curState' || true

    echo "[*] Done"
    echo "    Device: $SERIAL"
    echo "    IMEI:   $IMEI"
    echo "    Existing config already contains SSID: $SSID"
    exit 0
fi

echo "[*] Patching XML locally..."
python3 - "$LOCAL_ORIG" "$LOCAL_PATCHED" "$SSID" "$PASSWORD" <<'PY'
import sys
from pathlib import Path
from datetime import datetime

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
ssid = sys.argv[3]
password = sys.argv[4]

text = src.read_text(encoding="utf-8")

ssid_xml = f'&quot;{ssid}&quot;'
config_key = f'&quot;{ssid}&quot;WPA_PSK'

if f'<string name="SSID">{ssid_xml}</string>' in text:
    print(f'[+] SSID already present: {ssid}')
    dst.write_text(text, encoding="utf-8")
    sys.exit(0)

creation_time = datetime.now().strftime("time=%m-%d %H:%M:%S.000")

block = f"""
<Network>
<WifiConfiguration>
<string name="ConfigKey">{config_key}</string>
<string name="SSID">{ssid_xml}</string>
<null name="BSSID" />
<string name="PreSharedKey">&quot;{password}&quot;</string>
<null name="WEPKeys" />
<int name="WEPTxKeyIndex" value="0" />
<boolean name="HiddenSSID" value="false" />
<boolean name="RequirePMF" value="false" />
<byte-array name="AllowedKeyMgmt" num="1">02</byte-array>
<byte-array name="AllowedProtocols" num="1">03</byte-array>
<byte-array name="AllowedAuthAlgos" num="1">01</byte-array>
<byte-array name="AllowedGroupCiphers" num="1">0f</byte-array>
<byte-array name="AllowedPairwiseCiphers" num="1">06</byte-array>
<boolean name="Shared" value="true" />
<int name="WapiPskKeyType" value="-1" />
<null name="WapiAsCert" />
<null name="WapiUserCert" />
<int name="EapSimSlot" value="-1" />
<int name="AutoJoinNetwork" value="1" />
<int name="Status" value="2" />
<null name="FQDN" />
<null name="ProviderFriendlyName" />
<null name="LinkedNetworksList" />
<null name="DefaultGwMacAddress" />
<boolean name="ValidatedInternetAccess" value="false" />
<boolean name="NoInternetAccessExpected" value="false" />
<int name="UserApproved" value="0" />
<boolean name="MeteredHint" value="false" />
<int name="MeteredOverride" value="0" />
<boolean name="UseExternalScores" value="false" />
<int name="NumAssociation" value="0" />
<int name="CreatorUid" value="1000" />
<string name="CreatorName">android.uid.system:1000</string>
<string name="CreationTime">{creation_time}</string>
<int name="LastUpdateUid" value="1000" />
<string name="LastUpdateName">android.uid.system:1000</string>
<int name="LastConnectUid" value="1000" />
<boolean name="IsLegacyPasspointConfig" value="false" />
<long-array name="RoamingConsortiumOIs" num="0" />
</WifiConfiguration>
<NetworkStatus>
<string name="SelectionStatus">NETWORK_SELECTION_ENABLED</string>
<string name="DisableReason">NETWORK_SELECTION_ENABLE</string>
<null name="ConnectChoice" />
<long name="ConnectChoiceTimeStamp" value="-1" />
<boolean name="HasEverConnected" value="false" />
</NetworkStatus>
<IpConfiguration>
<string name="IpAssignment">DHCP</string>
<string name="ProxySettings">NONE</string>
</IpConfiguration>
</Network>
"""

marker = "</NetworkList>"
if marker not in text:
    print("[!] Could not find </NetworkList> in WifiConfigStore.xml", file=sys.stderr)
    sys.exit(1)

patched = text.replace(marker, block + "\n" + marker, 1)
dst.write_text(patched, encoding="utf-8")
print(f'[+] Added SSID: {ssid}')
PY

echo "[*] Pushing patched XML to device temp path..."
"${ADB[@]}" push "$LOCAL_PATCHED" "$REMOTE_TMP_XML" >/dev/null

echo "[*] Replacing remote WifiConfigStore.xml..."
"${ADB[@]}" shell "
cp '$REMOTE_TMP_XML' '$REMOTE_WIFI_XML' &&
chown system:system '$REMOTE_WIFI_XML' 2>/dev/null || chown system.system '$REMOTE_WIFI_XML' 2>/dev/null || true &&
chmod 600 '$REMOTE_WIFI_XML' &&
restorecon '$REMOTE_WIFI_XML' 2>/dev/null || true
"

echo "[*] Enabling Wi-Fi..."
"${ADB[@]}" shell svc wifi enable || true
sleep 8

echo "[*] Verifying SSID exists in remote XML..."
if "${ADB[@]}" shell "grep -F '<string name=\"SSID\">&quot;$SSID&quot;</string>' '$REMOTE_WIFI_XML'" >/dev/null; then
    echo "[+] SSID entry written successfully"
else
    echo "[!] SSID not found after write"
fi

echo "[*] Waiting a bit for association..."
sleep 5

echo "[*] Current Wi-Fi summary:"
"${ADB[@]}" shell dumpsys wifi 2>/dev/null | tr -d '\r' | grep -E 'Wi-Fi is|mNetworkInfo|SSID|BSSID|Supplicant state|curState' || true

echo "[*] Checking whether device appears connected to target SSID..."
if "${ADB[@]}" shell dumpsys wifi 2>/dev/null | tr -d '\r' | grep -F "$SSID" >/dev/null; then
    echo "[+] Device appears associated with SSID: $SSID"
else
    echo "[!] SSID was provisioned, but active connection to $SSID was not confirmed yet"
fi

echo "[*] Done"
echo "    Device: $SERIAL"
echo "    IMEI:   $IMEI"
echo "    Backup on device: $REMOTE_BACKUP_DIR/WifiConfigStore.xml.$NOW.bak"
echo "    Local original:   $LOCAL_ORIG"
echo "    Local backup:     ${LOCAL_ORIG}.bak"
echo "    Local patched:    $LOCAL_PATCHED"