@echo off
REM ============================================================
REM P0 STEP A (safe ladder), generic write path.
REM Loads a RAM-patched uboot-as-FDL2 whose partition dispatch
REM always takes the generic write path (strcmp patched to
REM return 1), because the dedicated sprd_nand_write_spl
REM boot-block writer deterministically resets the device.
REM
REM STEP A (this script): write STOCK splloader content back
REM through the generic path. Zero risk: content identical to
REM what is on flash now; validates commit and boot layout.
REM In-session readback saved to spl-readback3.bin.
REM
REM Enter download mode first: power off, hold RESET, plug USB.
REM After it finishes: power-cycle the device and check that the
REM stock system boots normally (LED solid, web 200). If YES,
REM proceed to run-p0-stepB.cmd (the patched SPL write).
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo STEP A: generic-path write of STOCK splloader + in-session readback
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1-ram-probe.bin 0x28007000 ^
  fdl x03-uboot-genericwrite.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  w splloader "%~dp0..\..\fdl-verification\stock-backups\splloader.bin" ^
  read_part splloader 0 262144 spl-readback3.bin ^
  reset
echo.
echo Power-cycle the device, verify stock boots (LED solid, web 200),
echo then run run-p0-stepB.cmd.
pause
