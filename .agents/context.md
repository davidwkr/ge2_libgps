# GE2 GNSS LibGPS Context

## Overview
This repository manages GNSS/GPS configurations and fixes for the **UNISOC SL8541E** (Spreadtrum) chipset, specifically the **GREENEYE2 (GE2)** module. 

The primary goal is to ensure stable and fast GPS locks on devices using this hardware, with specialized support for Argentine carriers (Movistar/Personal).

## Key Components
- **Configuration Files**: 
  - `config.xml`: Deep vendor settings for the GNSS module.
  - `supl.xml`: SUPL (Secure User Plane Location) server definitions.
  - `gps.conf`: Android framework-level GNSS settings.
- **Fix Scripts**:
  - `final_super_universal_fix.sh`: Universal framework sync.
  - `apply_claro_fix.sh`: Standalone fix specifically for Claro Argentina.
  - `apply_movistar_fix.sh`: Standalone fix specifically for Movistar Argentina.
  - `apply_movistar_no_cp_fix.sh`: Standalone fix for Movistar WITHOUT Control Plane.
  - `deploy_fix.sh`: Interactive tool to list devices and deploy any of the above fixes.
  - `legacy_movistar_fix.sh`: Specialized fix for Movistar networks.
  - `revert_to_stock_configs.sh`: Recompression of the original vendor states.

## Hardware/Environment
- **Chipset**: SL8541E (SC9832E related)
- **Interface**: `seth_lte0` for SUPL communication.
- **Paths**:
  - `/vendor/etc/`: Core GNSS configurations.
  - `/data/gnss/`: Runtime state and cache.
  - `/dev/sttygnss0`: Control/Data interface.

## AI Instructions
When working on this repo:
1. **Root Access**: All fix scripts must run with root permissions on the target device.
2. **Reboot Mandatory**: GNSS changes often require a full reboot or `gpsd` restart to take effect.
3. **Backup First**: Always check for `.bak` files before overwriting.
