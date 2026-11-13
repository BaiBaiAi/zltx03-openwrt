@echo off
REM ============================================================
REM Read back the splloader partition and save it as spl-readback.bin
REM for offline comparison (did the patched SPL actually commit?).
REM Enter download mode first: power off, hold RESET, plug USB
REM (LED off = correct mode).
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Reading back splloader partition...
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  read_part splloader 0 262144 spl-readback.bin ^
  reset
echo.
echo Done. spl-readback.bin is in fdl-verification.
pause
