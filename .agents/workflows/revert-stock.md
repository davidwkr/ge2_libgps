---
description: Revert GNSS configurations to stock factory state
---

1. Ensure target device is connected via ADB and has root access.
2. Push `revert_to_stock_configs.sh` to the device.
3. Set execution permissions:
   ```bash
   chmod +x /data/local/tmp/revert_to_stock_configs.sh
   ```
4. Run the script as root:
   ```bash
   su -c /data/local/tmp/revert_to_stock_configs.sh
   ```
5. Reboot the device.
