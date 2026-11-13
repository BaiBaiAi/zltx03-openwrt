@echo off
REM ============================================================
REM P1 experiment: full Option-B persistent flash.
REM   splloader  = x03-spl-noverify.bin  (SPL verify bypass)
REM   uboot      = x03-uboot-noverify.bin (system-verify wrapper returns 0)
REM   ubootbak   = same as uboot
REM   system     = system-linux414.ubifs (OpenWrt rootfs, no signature)
REM   everything else = stock (boot, sml, smlbak, recovery, prodnv ...)
REM
REM Only run this AFTER P0 confirmed that the BootROM accepts the
REM patched SPL (device booted normally).
REM
REM Expected: BootROM -> patched SPL -> stock SML -> patched U-Boot
REM   (system verify skipped) -> OpenWrt rootfs -> RNDIS enumerates,
REM   Windows adapter 192.168.10.2/24, ssh root@192.168.10.1.
REM
REM Rollback: run run-rollback-stock.cmd (writes stock system back;
REM the patched SPL+uboot boot the stock system fine).
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Writing patched SPL + patched uboot/ubootbak + OpenWrt system
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  w uboot "%~dp0..\..\fdl-verification\x03-uboot-noverify.bin" ^
  w ubootbak "%~dp0..\..\fdl-verification\x03-uboot-noverify.bin" ^
  w system "%~dp0..\..\firmware\dist\system-linux414.ubifs" ^
  w splloader "%~dp0..\..\fdl-verification\x03-spl-noverify.bin" ^
  reset
echo.
echo Watch for RNDIS enumeration, then: ssh root@192.168.10.1
pause
