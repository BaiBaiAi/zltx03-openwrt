@echo off
REM ============================================================
REM RECOVERY: restore stock ubootbak (SPL fallback partition).
REM ubootbak is NOT in the secure-part table, so this uses the
REM plain write path (same as system writes, proven reliable).
REM
REM Sequence in one session:
REM   1. read sml (damage check)
REM   2. w ubootbak = stock content (restore)
REM   3. read back ubootbak (verify landed)
REM   4. reset
REM
REM After reset: power-cycle and observe 90s. The device should
REM boot (either via the patched uboot or the restored ubootbak
REM fallback). Report LED/USB/web state + this log.
REM
REM Enter download mode first: power off, hold RESET, plug USB.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo RECOVERY: read sml + restore stock ubootbak + verify
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_part sml 0 786432 diag-sml2.bin ^
  w ubootbak "%~dp0..\..\fdl-verification\stock-backups\ubootbak.bin" ^
  read_part ubootbak 0 1310720 diag-ubootbak-after.bin ^
  reset
echo.
echo Power-cycle and observe 90s, then report.
pause
