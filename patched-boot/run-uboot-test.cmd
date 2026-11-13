@echo off
REM ============================================================
REM UBOOT TEST v2: write the PATCHED uboot via the PATCHED mini
REM fdl2 (x03-fdl2-dl2noverify.bin = stock fdl2 with the
REM orca_cpe_dl_verify call NOPed @0x16E30).
REM
REM Rationale: the mini fdl2's write path is proven reliable
REM (morning system writes, SHA-verified). The previous uboot
REM test used uboot-as-FDL2 whose writes silently no-op.
REM uboot is a secure-table partition, so its END_DATA normally
REM runs orca_cpe_dl_verify first - that gate is now NOPed.
REM
REM Safety: if the SPL rejects the patched uboot, it falls back
REM to ubootbak (stock) and the stock system boots - device
REM survives in every outcome.
REM
REM Enter download mode first: power off, hold RESET, plug USB.
REM In-session readback: uboot-readback2.bin.
REM After reset: observe 90s and report LED/USB/web state.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo UBOOT TEST v2: patched mini fdl2 + write PATCHED uboot
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1-ram-probe.bin 0x28007000 ^
  fdl x03-fdl2-dl2noverify.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  w uboot "%~dp0..\..\fdl-verification\x03-uboot-noverify.bin" ^
  read_part uboot 0 1310720 uboot-readback2.bin ^
  reset
echo.
echo Power-cycle and observe 90s, then report.
pause
