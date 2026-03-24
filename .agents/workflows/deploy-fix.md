---
description: Run the interactive GNSS fix deployment tool
---

1. Connect target device(s) via USB.
2. Ensure ADB debugging and Root access are enabled on the target(s).
3. Run the deployment tool from the repository root:
// turbo
   ```bash
   chmod +x deploy_fix.sh && ./deploy_fix.sh
   ```
4. Follow the on-screen prompts to:
   - Select the target device (detected via serial, model, and MCC/MNC).
   - Choose the appropriate configuration (Universal, Claro, Movistar, or Stock).
5. The deployment tool will:
   - Push the selected standalone fix to `/data/local/tmp/`.
   - Run the fix with `su` permissions.
   - Automatically trigger a system reboot.
