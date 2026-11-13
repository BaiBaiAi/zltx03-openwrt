@echo off
REM ============================================================
REM PROBE C v2: clean chain + partition-name readback baseline.
REM READ ONLY. No partition is written.
REM
REM 2026-11-13 REAL RUN: the clean chain WORKS.
REM   SEND fdl1.bin -- EXEC FDL1 -- CHECK_BAUD FDL1 --
REM   "Spreadtrum Boot Block version 1.1" -- CMD_CONNECT FDL1 --
REM   KEEP_CHARGE FDL1 -- SEND fdl2.bin -- "FDL2: incompatible
REM   partition" (normal DA info) -- EXEC FDL2 -- DISABLE_TRANSCODE
REM   -- "Storage is nand".
REM   This CONFIRMS exec_addr 0x3f28 is NOT needed: FDL1 and FDL2
REM   both start on the clean chain.
REM
REM BUT THE ORIGINAL PROBE QUESTION CANNOT BE ANSWERED THIS WAY.
REM   read_flash 0 0 262144 returned
REM     unexpected response (0x00fe)
REM     Read Flash Done: ... target: 0x40000, read: 0x0
REM   0xFE = BSL_REP_UNSUPPORTED_COMMAND (spd_cmd.h:233). dump_flash
REM   (common.c:897-930) sends BSL_CMD_READ_FLASH, which this FDL2
REM   simply does not implement. So there is NO address-based READ
REM   on this device, and addr 0 mapping stays UNVERIFIED.
REM
REM IMPORTANT: this does NOT kill the address-based WRITE idea.
REM   write_flash uses BSL_CMD_START_DATA + MIDST/END_DATA (the same
REM   basic download path used to upload FDL2), a different command
REM   family from READ_FLASH. It may still work.
REM
REM v3 CHANGE: replace read_flash with read_part splloader (the
REM   partition-name path proven in round 6) to get a reliable
REM   READBACK baseline for the write PoC. The "p" command is
REM   REMOVED: it only prints the host-side cached partition table
REM   (spd_dump.c:1189-1198), and read_part splloader uses a
REM   hardcoded branch in get_partition_info (common.c:1978).
REM   2026-11-13 REAL RUN: Read Part Done ... read: 0x40000 at
REM   3.97Mb/s, fc /b identical to stock splloader (READPART-OK).
REM   Prefer run-probe-fdl2-all.cmd: it adds eFuse reads in the
REM   same one-shot session and avoids the interactive prompt.
REM
REM RESULT
REM   READPART-OK = split readback works; the write PoC can use it
REM      to decide whether the patched SPL landed.
REM   NO OUTPUT   = read_part failed; STOP, do not attempt a write.
REM
REM SIDE NOTE: the tool drops into an "FDL2" interactive prompt
REM   after the argument list is consumed. That is spd_dump's
REM   interactive mode (spd_dump.c:546-575); all commands can be
REM   typed there without power-cycling. e_efuse_read block_id is available
REM   (spd_dump.c:712, common.c:3856) and is the cleanest way to
REM   inspect the secure-boot fuse state. See run-probe-efuse.cmd.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
if exist readpart-baseline.bin del readpart-baseline.bin
echo PROBE C v2: clean chain + read_part baseline (read-only)
spd_dump.exe --wait 600 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_part splloader 0 262144 readpart-baseline.bin
echo.
if not exist readpart-baseline.bin goto nofile
fc /b readpart-baseline.bin stock-backups\splloader.bin >nul
if errorlevel 1 goto mismatch
echo READPART-OK: readback equals stock splloader. Readback path is usable.
echo Next: run-write-spl-addrpath.cmd (v3 uses this same readback).
goto done
:mismatch
echo MISMATCH: readback differs from stock. Investigate before any write.
goto done
:nofile
echo NO OUTPUT: read_part failed. Check the log above. STOP here.
:done
echo Note: an FDL2 interactive prompt is not a hang. Type exit to leave.
echo Power off the device by hand. Nothing was written.
pause
