@echo off
REM ============================================================
REM P0 experiment: write ONLY the no-verify SPL (256 KB).
REM Everything else stays stock. Purpose: determine whether the
REM BootROM enforces a signature on the SPL loaded from NAND.
REM
REM Expected if BootROM does NOT verify SPL:
REM   device boots stock system normally, USB 1782:4056 appears,
REM   http://192.168.10.1/ returns HTTP 200.
REM Expected if BootROM DOES verify SPL:
REM   no boot. Recovery: run run-rollback-stock.cmd or re-enter
REM   download mode (power off, hold RESET, plug USB) and write
REM   the stock splloader back.
REM
REM Enter download mode first: power off completely, hold RESET,
REM plug USB (BootROM "SPRD U2S Diag" appears).
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Writing patched SPL (no partition verify) - RAM/stock untouched otherwise
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  w splloader "%~dp0..\..\fdl-verification\x03-spl-noverify.bin" ^
  reset
echo.
echo After reset: watch for 1782:4056 and check http://192.168.10.1/
pause
