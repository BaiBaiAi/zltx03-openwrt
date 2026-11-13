@echo off
REM ============================================================
REM P0 STEP B v2: write the PATCHED SPL via a doubly-patched
REM RAM dloader (x03-uboot-dl2noverify.bin):
REM   1. partition dispatch forced to the generic write path
REM      (strcmp patched, @0x15564)
REM   2. dl_download_end's image-verify call NOPed (@0x16148)
REM      - root cause of all previous commit resets: splloader
REM        is in the secure-part table, so END_DATA triggers
REM        orca_cpe_dl_verify first; a modified SPL fails it
REM        and the dloader resets the device.
REM In-session readback saved to spl-readback4.bin.
REM
REM Enter download mode first: power off, hold RESET, plug USB.
REM After it finishes: power-cycle and observe 90s.
REM   - stock system boots (LED solid, web 200)
REM       -> P0 PASSED: BootROM accepts the patched SPL.
REM   - no boot
REM       -> BootROM rejects. Recover: run-p0-stepA.cmd
REM          (restores stock SPL via the same proven path).
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo STEP B v2: generic path + no dl-verify, write PATCHED splloader
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1-ram-probe.bin 0x28007000 ^
  fdl x03-uboot-dl2noverify.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  w splloader "%~dp0..\..\fdl-verification\x03-spl-noverify.bin" ^
  read_part splloader 0 262144 spl-readback4.bin ^
  reset
echo.
echo Power-cycle and observe 90s. Boot OK = P0 passed.
pause
