@echo off
REM ============================================================
REM PROBE E: read eFuse blocks. ZERO writes, ZERO fuse changes.
REM
REM Purpose: settle the secure-boot fuse question left open by
REM   PROBE A. PROBE A only proved that BootROM accepts a modified
REM   FDL1 without any host-side bypass; a BootROM that checks the
REM   certificate but not the payload hash behaves the same whether
REM   or not secure boot is fused. Reading eFuse is the direct way.
REM
REM Source:
REM   spd_cmd.h:225  BSL_CMD_E_EFUSE_READ = 0x78
REM   spd_cmd.h:231  BSL_REP_E_EFUSE_READ = 0xE8
REM   spd_dump.c:712  "e_efuse_read block_id"
REM   common.c:3856  do_e_efuse_read() prints
REM                  eFuse[0xN] = 0xXXXXXXXX (4 bytes, LE)
REM
REM SAFETY: this only READS. It never issues 0x1C
REM   (ENABLE_SECUREBOOT) or any fuse-write command. Never type
REM   anything else that writes a fuse at the interactive prompt.
REM
REM PRACTICAL NOTE: do_e_efuse_read() calls ERR_EXIT on a read
REM   timeout, so a scripted scan stops at the first block the FDL2
REM   refuses. If that happens, just re-run in the interactive
REM   FDL2 interactive prompt and type the blocks one at a time:
REM     e_efuse_read 0
REM     e_efuse_read 1
REM   That prompt appears whenever spd_dump runs out of arguments
REM   (spd_dump.c:546-575) and accepts the full command set. It is
REM   printed as FDL2 followed by a greater-than character.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo PROBE E: reading eFuse blocks 0..15 (read-only)
spd_dump.exe --wait 600 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  e_efuse_read 0 ^
  e_efuse_read 1 ^
  e_efuse_read 2 ^
  e_efuse_read 3 ^
  e_efuse_read 4 ^
  e_efuse_read 5 ^
  e_efuse_read 6 ^
  e_efuse_read 7 ^
  e_efuse_read 8 ^
  e_efuse_read 9 ^
  e_efuse_read 10 ^
  e_efuse_read 11 ^
  e_efuse_read 12 ^
  e_efuse_read 13 ^
  e_efuse_read 14 ^
  e_efuse_read 15
echo.
echo Look for "eFuse[0xN] = 0xXXXXXXXX" lines above.
echo An FDL2 interactive prompt is not a hang. Type exit to leave.
echo Power off the device by hand. Nothing was written.
pause
