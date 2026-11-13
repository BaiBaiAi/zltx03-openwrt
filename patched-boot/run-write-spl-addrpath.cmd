@echo off
REM ============================================================
REM MINIMAL PoC: write the PATCHED SPL through the address-based
REM BSL path (write_flash), bypassing the partition-name lookup.
REM
REM !!! THIS WRITES TO NAND BLOCK 0. READ THE RISK BLOCK BELOW !!!
REM
REM PREREQUISITE: run-probe-addrpath-clean.cmd v2 must print
REM   READPART-OK, i.e. read_part splloader works on this FDL2.
REM PREREQUISITE: run-probe-bootrom-verify.cmd (PROBE A) passed on
REM   2026-11-13, i.e. BootROM accepts a modified FDL1 without any
REM   host-side bypass. This raises the chance that a modified NAND
REM   SPL will boot too, but it does NOT prove the fuse state.
REM   P0 (power-cycle after a confirmed landed write) is the only
REM   real verdict on the NAND boot path.
REM
REM v3 CHANGES (2026-11-13, after PROBE C ran):
REM   1) CLEAN chain: PROBE B (with exec_addr 0x3f28) lost the device
REM      right after EXEC FDL1; PROBE A/C without it reached FDL1
REM      and FDL2 ("Storage is nand"). No custom exec stub needed.
REM   2) READBACK REVERTED to read_part splloader. PROBE C proved
REM      read_flash returns 0xFE = BSL_REP_UNSUPPORTED_COMMAND
REM      (common.c:897-930 sends BSL_CMD_READ_FLASH, not implemented
REM      by this FDL2), reading 0 bytes. The v2 idea of an all-address
REM      transaction is impossible: only the WRITE side is address
REM      based here. read_part is the proven round-6 path.
REM   3) BECAUSE addr 0 mapping could not be verified by a read,
REM      this PoC is now also the address-mapping test: if the
REM      patched bytes show up at the START of splloader on readback,
REM      addr 0 was correct; if nothing changed, we cannot tell
REM      "wrong address" from "write blocked". Treat NOT LANDED
REM      as inconclusive, not as a final negative.
REM   4) v4: removed the "p" command. "p" only prints the host-side
REM      cached partition table (spd_dump.c:1189-1198) and sends
REM      nothing to the device; read_part splloader uses a
REM      hardcoded branch in get_partition_info (common.c:1978).
REM      Also do NOT rely on the interactive prompt: it can sit
REM      idle until the device drops. Keep every command in the
REM      argument list so the run finishes without human pauses.
REM
REM WHY PATCHED CONTENT: a control write using stock content cannot
REM distinguish "write succeeded" from "write skipped" (round 14
REM lesson). The patched image differs by 8 bytes at 0x8CAC and
REM 0x28CAC, so an in-session readback is decisive.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM
REM RESULT
REM   readback == x03-spl-noverify.bin  -- LANDED. Power-cycle and
REM      observe 90s: stock system booting = P0 PASSED (BootROM
REM      accepts the patched SPL) -- proceed to P1.
REM   readback == stock splloader        -- NOT LANDED: either the
REM      write was blocked, or addr 0 is not splloader (unverified,
REM      since read_flash is unsupported). Do NOT power-cycle for
REM      P0; the device is still stock and safe. This result is
REM      INCONCLUSIVE on the write path, not a final negative.
REM   usb_send failed at END_DATA       -- commit triggered a reset;
REM      re-enter download mode and read splloader to find out.
REM
REM ROLLBACK (any state): re-enter download mode, then run
REM   run-recover-full.cmd  (stock system + uboot)
REM   run-rollback-stock.cmd (stock splloader / uboot / ubootbak)
REM All stock images are in fdl-verification\stock-backups\.
REM
REM NOTE: sendcmd/sendcmdv are NOT compiled into this spd_dump build,
REM so BSL 0x1B (ENABLE_WRITE_FLASH) cannot be issued with this tool.
REM If the write is blocked, that is the next thing to build.
REM NEVER issue BSL 0x1C (ENABLE_SECUREBOOT): it may burn a fuse.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
if exist spl-addrpath-readback.bin del spl-addrpath-readback.bin
echo PoC: clean-chain address write of patched SPL + in-session readback
spd_dump.exe --wait 600 ^
  fdl fdl1.bin 0x28007000 ^
  fdl fdl2.bin 0x9efffe00 exec ^
  skip_confirm 1 ^
  write_flash x03-spl-noverify.bin 0 ^
  read_part splloader 0 262144 spl-addrpath-readback.bin
echo.
if not exist spl-addrpath-readback.bin goto nofile
fc /b spl-addrpath-readback.bin x03-spl-noverify.bin >nul
if errorlevel 1 goto notlanded
echo LANDED: patched SPL is on NAND. Power-cycle for the P0 verdict.
goto done
:notlanded
echo NOT LANDED: no patched bytes (blocked OR wrong addr). Inconclusive.
echo Device is still stock and safe. Do NOT power-cycle for P0.
goto done
:nofile
echo NO READBACK: commit may have reset the device. Re-read splloader.
:done
echo Power off the device by hand before the next experiment.
pause
