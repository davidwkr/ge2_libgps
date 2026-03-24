---
description: Enable persistent boot-time GNSS logging
---

1. Push `setup_boot_logging.sh` to the device.
2. Run the script as root:
   ```bash
   su -c /data/local/tmp/setup_boot_logging.sh
   ```
3. This adds persistent logging properties (`persist.sys.gnss.log.enable`).
4. Reboot the device to start capturing logs.
