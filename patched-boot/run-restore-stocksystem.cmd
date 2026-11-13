@echo off
REM ============================================================
REM Restore the stock system partition (rollback for P1).
REM Enter download mode first: power off, hold RESET, plug USB.
REM In-session readback of the first 256KB: sys-restore-verify.bin
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Restoring stock system (37.8MB) + head readback
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  w system "%~dp0..\..\fdl-verification\stock-backups\system.bin" ^
  read_part system 0 262144 sys-restore-verify.bin ^
  reset
echo.
echo Power-cycle, then verify the stock system boots (web 200).
pause
