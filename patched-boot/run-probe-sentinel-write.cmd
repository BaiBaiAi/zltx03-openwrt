@echo off
REM ============================================================
REM PROBE G: 4-byte sentinel write via the address BSL path.
REM
REM WHY: PROBE F proved read_part splloader works (3.21 Mb/s) and
REM   that e_efuse_read is NOT in this spd_dump.exe build. The
REM   remaining unknown is whether the address-based START_DATA
REM   path can land bytes on NAND without a partition name. Writing
REM   a whole patched SPL to test that is needlessly risky. This
REM   probe changes only 4 bytes instead.
REM
REM TARGET: offset 0x3F800 of splloader. Verified offline that
REM   0x3F800..0x40000 of the stock SPL is entirely 0xFF padding.
REM   It is outside the DHTB header (0x200) and outside the signed
REM   payload (mImgSize 0xCBC0), so the boot chain is unaffected
REM   even if the write lands. Both SPL copies are identical.
REM
REM COMMAND: write_word 0x3F800 0x5A5A5A5A
REM   spd_dump.c:758-765 calls send_buf(), which emits
REM   BSL_CMD_START_DATA with an 8-byte payload (BE addr + size)
REM   and NO partition name. The safe table matches by name, so
REM   this should not hit the dl verification gate.
REM
REM VERDICT
REM   readback == stock-spl-sentinel.bin   ADDRESS WRITE LANDED.
REM      The address path writes NAND and 0x3F800 maps into
REM      splloader. Only now is run-write-spl-addrpath.cmd
REM      meaningful. Do NOT power-cycle for P0 yet: a sentinel
REM      in padding says nothing about patched SPL verification.
REM   readback == stock splloader          NOT LANDED. Either the
REM      write was blocked, or START_DATA addr is a RAM load
REM      address on this FDL2 (fdl uploads use the same send_buf
REM      with RAM addresses). Device is still stock and safe.
REM   anything else                       ABNORMAL. Do not power
REM      cycle. Compare the two dumps by hand first.
REM
REM RISK: 4 bytes inside 0xFF padding. Even a landed write leaves
REM   the device bootable. No erase, no fuse, no 0x1C, no 0x1B.
REM   NEVER issue 0x1C (ENABLE_SECUREBOOT).
REM
REM PREREQUISITE: run-probe-fdl2-all.cmd v2 prints READPART-OK.
REM Enter download mode: power off fully, hold RESET, plug USB.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
if exist sentinel-readback.bin del sentinel-readback.bin
echo PROBE G: 4-byte sentinel via address path (readback verified)
spd_dump.exe --wait 600 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_part splloader 0 262144 sentinel-before.bin ^
  write_word 0x3F800 0x5A5A5A5A ^
  read_part splloader 0 262144 sentinel-readback.bin ^
  reset
echo.
if not exist sentinel-readback.bin goto nofile
for %%F in (sentinel-readback.bin) do if not "%%~zF"=="262144" goto shortfile
fc /b sentinel-readback.bin stock-spl-sentinel.bin >nul
if errorlevel 1 goto notlanded
echo LANDED: address write reached NAND padding. Boot chain unchanged.
echo Next: only now is run-write-spl-addrpath.cmd meaningful.
goto done
:notlanded
fc /b sentinel-readback.bin stock-backups\splloader.bin >nul
if errorlevel 1 goto abnormal
echo NOT LANDED: readback equals stock. Device is still stock and safe.
echo The address path is blocked, or addr is a RAM load address.
goto done
:abnormal
echo ABNORMAL: readback matches neither baseline. Do NOT power-cycle.
echo Inspect sentinel-before.bin and sentinel-readback.bin by hand.
goto done
:shortfile
echo SHORT READBACK: incomplete transfer. Re-run; do not conclude.
goto done
:nofile
echo NO READBACK: device dropped before the second read_part.
:done
echo A trailing timeout after reset is expected.
echo If an FDL2 prompt appears, do not type anything; close the window.
echo Power off the device by hand before the next experiment.
pause
