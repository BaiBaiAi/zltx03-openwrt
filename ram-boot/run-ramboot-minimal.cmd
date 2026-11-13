@echo off
REM ============================================================
REM X03 RAM boot test A: minimal initramfs + USB serial marker
REM v3 (corrected sequence):
REM   fdl fdl1        -> auto-exec + connect FDL1 (no explicit exec here!)
REM   fdl kernel/dtb/initramfs/stub -> uploaded through FDL1 (528B packets, slow)
REM   exec            -> FDL1 jumps to stub (must be last upload) -> kernel
REM No partition is written. Recovery = press RESET / replug USB.
REM
REM NOTE: the kernel upload is ~21800 small packets and can take
REM several minutes. Do NOT interrupt. After the final exec the
REM spd_dump window may print timeout errors while it waits for a
REM "FDL2" that is now our running kernel - that is EXPECTED, just
REM watch the USB watch script in the other window.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Uploading kernel (slow, minutes) + DTB + minimal initramfs + stub, then exec
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1-ram-probe.bin 0x28007000 ^
  fdl stock-kernel.bin 0x80080000 ^
  fdl "%~dp0x03-minimal-nopsci.dtb" 0x85000000 ^
  fdl "%~dp0..\..\firmware\dist\x03-minimal-initramfs.cpio.gz" 0x86000000 ^
  fdl "%~dp0booter-stub.bin" 0x9efffe00 ^
  exec
echo.
echo If USB 1782:000b enumerated, open the MI_00 serial port at 115200 8N1.
pause
