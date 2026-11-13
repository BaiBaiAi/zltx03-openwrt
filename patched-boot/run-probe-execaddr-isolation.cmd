@echo off
REM ============================================================
REM PROBE D: isolate the exec_addr injection. ZERO writes.
REM
REM Question: was PROBE B's "device removed" caused by the
REM   custom_exec_no_verify_3f28.bin injection, or was it a
REM   one-off USB / power-cycle timing problem?
REM
REM This script sends ONLY the first stage with exec_addr enabled,
REM   exactly as PROBE B did, but stops before FDL2. Compare with
REM   PROBE A (same first stage, no exec_addr): A reached FDL1.
REM
REM READ
REM   CHECK_BAUD FDL1 + "Spreadtrum Boot Block version 1.1"
REM       -- injection is fine; PROBE B's failure was incidental.
REM   CHECK_BAUD FAIL -- device removed, same as PROBE B
REM       -- the injection is what breaks the chain on this device.
REM          Use the clean chain in all following scripts.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM Power off by hand when done. Nothing is written.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo PROBE D: exec_addr 0x3f28 + stock FDL1 only (isolation, read-only)
spd_dump.exe --wait 600 exec_addr 0x3f28 fdl fdl1.bin 0x28007000
echo.
echo Compare the CHECK_BAUD result with PROBE A.
echo Power off the device by hand. Nothing was written.
pause
