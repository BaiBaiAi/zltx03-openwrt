@echo off
REM ============================================================
REM PROBE F v2: one-shot FDL2 SPL readback baseline. READ ONLY.
REM
REM v2 CHANGE (round 24): ALL e_efuse_read commands were removed.
REM   This spd_dump.exe does NOT contain e_efuse_read at all: the
REM   command string table inside the binary has no "efuse" match,
REM   and the built-in help lists no such command. The source tree
REM   in _ref/spreadtrum_flash is a DIFFERENT build.
REM   An unknown command hits spd_dump.c:1796-1798: print_help()
REM   plus argc = 1, which DISCARDS every remaining argument
REM   (including the trailing reset) and drops into the interactive
REM   FDL2 prompt. That is exactly what PROBE F run 2 printed.
REM
REM SEQUENCE (clean chain, no exec_addr, no p, no read_flash):
REM   fdl fdl1.bin      auto EXEC_DATA, FDL1 connects
REM   fdl fdl2.bin      uploaded through FDL1
REM   exec              FDL2 starts, prints "Storage is nand"
REM   read_part         262144-byte SPL baseline
REM   reset             closes the session so the checks below run
REM
REM A trailing "timeout reached" after reset is EXPECTED and
REM   harmless: FDL2 reboots before answering NORMAL_RESET.
REM
REM SAFETY: reads only. NEVER issue 0x1C or any fuse-write command.
REM Enter download mode: power off fully, hold RESET, plug USB.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
if exist readpart-baseline.bin del readpart-baseline.bin
echo PROBE F v2: clean chain + SPL readback baseline (read-only)
spd_dump.exe --wait 600 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_part splloader 0 262144 readpart-baseline.bin ^
  reset
echo.
if not exist readpart-baseline.bin goto nofile
for %%F in (readpart-baseline.bin) do if not "%%~zF"=="262144" goto shortfile
fc /b readpart-baseline.bin stock-backups\splloader.bin >nul
if errorlevel 1 goto mismatch
echo READPART-OK: 262144 bytes, byte-identical to stock splloader.
goto done
:mismatch
echo MISMATCH: full-size readback differs from stock. Investigate.
goto done
:shortfile
echo SHORT READBACK: file is not 262144 bytes. Incomplete transfer.
echo Delete it and re-run. Do NOT read this as a changed SPL.
goto done
:nofile
echo NO BASELINE: read_part failed or the device dropped early.
:done
echo If an FDL2 prompt appears, do not type anything; close the window.
echo Power off the device by hand. Nothing was written.
pause
