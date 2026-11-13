@echo off
REM ============================================================
REM PROBE B: verify that address-based BSL commands map addr 0
REM to the first 256 KiB of NAND (the splloader partition).
REM READ ONLY. No partition is written.
REM
REM SUPERSEDED 2026-11-13: the real run of this script died with
REM   "CHECK_BAUD FAIL -> device removed" right after EXEC FDL1,
REM   before FDL2 or read_flash ran. Use
REM   run-probe-addrpath-clean.cmd (PROBE C) instead: same read,
REM   but without the exec_addr 0x3f28 injection that PROBE A
REM   showed to be unnecessary. This file is kept only as the
REM   record of that failed run.
REM
REM Background (spreadtrum_flash/common.c):
REM   w <name>      -> select_partition -> START_DATA with a
REM                    72-byte UTF-16 partition name. The device
REM                    matches that name against the secure-part
REM                    table and triggers the dl verify gate.
REM   write_flash   -> send_buf -> START_DATA with ONLY 8 bytes
REM                    (big-endian address + length), no name.
REM This probe checks the READ side (read_flash) of that path.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM
REM Result:
REM   MATCH    = addr 0 maps to splloader start; go on to
REM              run-write-spl-addrpath.cmd
REM   MISMATCH = address path interprets addr differently; STOP.
REM              Do not attempt any address-based write.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo PROBE B: read_flash 0 0 262144 (read-only)
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_flash 0 0 262144 addr-probe.bin ^
  reset
echo.
if not exist addr-probe.bin goto nofile
fc /b addr-probe.bin stock-backups\splloader.bin >nul
if errorlevel 1 goto mismatch
echo MATCH: addr 0 maps to stock splloader. Address path is usable.
goto done
:mismatch
echo MISMATCH: address path does NOT map as expected. STOP here.
goto done
:nofile
echo NO OUTPUT: read_flash produced no file. Check the log above.
:done
pause
