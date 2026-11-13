@echo off
REM ============================================================
REM P0 attempt 3: disable rawdata mode, then write patched SPL
REM through the legacy BSL write path (528B chunks).
REM Control evidence so far:
REM   - w uboot (non-boot-block) commits cleanly at 10Mb/s
REM   - w splloader crashes at commit in rawdata path (x2, plus
REM     once via the mini fdl2)
REM Enter download mode first: power off, hold RESET, plug USB.
REM Then run read-spl-verify.cmd to check what landed.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo P0 attempt 3: rawdata 0 + write splloader
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  rawdata 0 ^
  w splloader "%~dp0..\..\fdl-verification\x03-spl-noverify.bin" ^
  reset
echo.
echo Then run read-spl-verify.cmd.
pause
