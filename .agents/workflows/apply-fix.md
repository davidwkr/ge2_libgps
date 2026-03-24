---
description: Apply the universal GNSS fix for SL8541E
---

1. Ensure target device is connected via ADB and has root access.
2. Push `final_super_universal_fix.sh` to the device (e.g., `/data/local/tmp/`).
3. Set execution permissions:
   ```bash
   chmod +x /data/local/tmp/final_super_universal_fix.sh
   ```
4. Run the script as root:
   ```bash
   su -c /data/local/tmp/final_super_universal_fix.sh
   ```
5. Reboot the device.
6. Verify GNSS status using `logcat -s SPRDGNSS`.
