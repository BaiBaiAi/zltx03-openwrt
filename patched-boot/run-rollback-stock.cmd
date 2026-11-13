@echo off
REM ============================================================
REM Rollback: restore stock splloader / uboot / ubootbak / system.
REM Requires the backup binaries extracted from
REM ZLT-X03-backups-20261113.zip into fdl-verification\stock-backups\:
REM   stock-backups\splloader.bin  (full\splloader.bin)
REM   stock-backups\uboot.bin      (full\uboot.bin)
REM   stock-backups\ubootbak.bin   (full\ubootbak.bin, read 2026-11-13)
REM   stock-backups\system.bin     (win\system.bin)
REM ubootbak was not in the zip; read it again if missing:
REM   spd_dump.exe --wait 600 exec_addr 0x3f28 fdl fdl1.bin 0x28007000 fdl fdl2.bin 0x9efffe00 exec skip_confirm 1 r ubootbak
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
if not exist "stock-backups\splloader.bin" echo MISSING stock-backups\splloader.bin - extract the backup zip first & pause & exit /b 1
if not exist "stock-backups\ubootbak.bin" echo MISSING stock-backups\ubootbak.bin - read it from the device first & pause & exit /b 1
echo Restoring stock splloader / uboot / ubootbak / system
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  w system "stock-backups\system.bin" ^
  w uboot "stock-backups\uboot.bin" ^
  w ubootbak "stock-backups\ubootbak.bin" ^
  w splloader "stock-backups\splloader.bin" ^
  reset
echo.
echo After reset the stock firmware should boot (1782:4056, web 200).
pause
