@echo off
REM ============================================================
REM P1: flash the OpenWrt system partition (7.36MB UBIFS).
REM The currently-running uboot either is the patched one
REM (system verify bypassed, OpenWrt boots = GOAL) or the
REM stock fallback (strict verify = hang, restore below).
REM
REM Enter download mode first: power off, hold RESET, plug USB.
REM In-session readback: system-openwrt-verify.bin (first 7.36MB).
REM
REM After reset observe 90s:
REM   - OpenWrt RNDIS enumerates / 192.168.10.1 reachable
REM       = SUCCESS: persistent OpenWrt.
REM   - no boot
REM       = SPL rejected the patched uboot. Restore stock:
REM         re-enter download mode and run
REM         run-restore-stocksystem.cmd
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo P1: write OpenWrt system + in-session readback
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  w system "%~dp0..\..\firmware\dist\system-linux414.ubifs" ^
  read_part system 0 7364608 system-openwrt-verify.bin ^
  reset
echo.
echo Power-cycle and observe 90s. Report RNDIS / LED / web.
pause
