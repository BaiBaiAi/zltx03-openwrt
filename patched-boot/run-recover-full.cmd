@echo off
REM ============================================================
REM FULL RECOVERY: restore stock system + stock uboot.
REM The ubootbak fallback rejected the OpenWrt system because
REM the SPL enforced the uboot signature and fell back to the
REM stock uboot, which strictly verifies the system partition.
REM
REM Enter download mode first: FULLY power off (long-press
REM power), then hold RESET and plug USB. Do not rely on the
REM U2S Diag shown after normal power-on (that is the hung
REM uboot, not the BootROM).
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo FULL RECOVERY: stock system + stock uboot
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  w system "%~dp0..\..\fdl-verification\stock-backups\system.bin" ^
  w uboot "%~dp0..\..\fdl-verification\stock-backups\uboot.bin" ^
  reset
echo.
echo Power-cycle: stock system should boot (LED solid, web 200).
pause
