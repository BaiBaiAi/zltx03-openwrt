@echo off
REM ============================================================
REM DIAGNOSTIC: read back splloader / uboot / ubootbak / sml
REM (read-only, zero risk). Enter download mode first:
REM power off, hold RESET, plug USB (LED off).
REM Output: diag-spl.bin / diag-uboot.bin / diag-ubootbak.bin /
REM         diag-sml.bin in fdl-verification.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Reading splloader / uboot / ubootbak / sml...
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_part splloader 0 262144 diag-spl.bin ^
  read_part uboot 0 1310720 diag-uboot.bin ^
  read_part ubootbak 0 1310720 diag-ubootbak.bin ^
  read_part sml 0 786432 diag-sml.bin ^
  reset
echo.
echo Send the log to the assistant for damage mapping.
pause
