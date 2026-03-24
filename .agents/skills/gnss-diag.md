# GNSS Diagnosis Skill (GE2/SL8541E)

## Log Interpretation
When analyzing `logcat` for GE2 GNSS:

- **Missing SUPL Connection**:
  - Look for: `SUPL_CONN_FAIL` or `seth_lte0: not found`.
  - Fix: Ensure the `seth_lte0` interface is up and the carrier APN allows SUPL traffic.
- **Clock Sync Issues**:
  - Look for: `UTC time is old` or `GPS time jumped`.
  - Fix: Check the `date` command output. SL8541E often needs manual time sync if NTP fails.
- **CMCC Interference**:
  - Look for: `CMCC-MODE active`.
  - Fix: Disable `CMCC-ENABLE` in `config.xml` to allow standard carrier configs.

## Key Properties
- `persist.sys.sprd.gnss.mode`: Should be `msb` (Mobile Station Based) for typical SUPL.
- `persist.sys.gnss.log.path`: Usually `/data/gnss/log/`.
