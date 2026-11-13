@echo off
REM ============================================================
REM P0 attempt 2: write splloader via the X03's own full U-Boot
REM acting as FDL2 (full NAND driver stack instead of the mini
REM fdl2 whose commit crashes on boot blocks).
REM
REM Steps in one session (all zero-risk content):
REM   1. connect stock FDL1 (signed, auto-exec)
REM   2. upload stock uboot as stage-2 (signed, passes verify)
REM   3. w uboot     = stock uboot content (identical bytes, no-op)
REM      -> control test: non-boot-block write must commit cleanly
REM   4. w splloader = patched SPL (the actual experiment)
REM   5. reset
REM
REM Enter download mode first: power off, hold RESET, plug USB
REM (LED off = correct mode).
REM After it finishes, run read-spl-verify.cmd to confirm.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo P0 attempt 2 via uboot-as-FDL2
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl stock-uboot.bin 0x9efffe00 exec ^
  w uboot "%~dp0..\..\fdl-verification\stock-backups\uboot.bin" ^
  w splloader "%~dp0..\..\fdl-verification\x03-spl-noverify.bin" ^
  reset
echo.
echo Then run read-spl-verify.cmd and compare.
pause
