@echo off
REM ============================================================
REM FDL1 stage blk_size probe (RAM only, no partition written).
REM
REM Problem: the RAM-boot upload failed at ~3 MiB because FDL1
REM uses 528-byte packets with a per-packet ACK (6000+ packets).
REM
REM Source evidence (spreadtrum_flash/spd_dump.c):
REM   line 822: fdl uses "blk_size ? blk_size : 528" when FDL1 is
REM             connected, so the packet size IS configurable.
REM   line 1497: blk_size command has NO stage check in the host.
REM   line 1502: value is clamped to 0xf800 and aligned to 0x800.
REM The help text says "fdl2 stage only", but that is documentation,
REM not a host-side restriction. Whether the DEVICE's FDL1 accepts
REM 62 KiB MIDST packets is exactly what this probe tests.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM
REM RESULT:
REM   probe100k.bin uploads cleanly -> FDL1 accepts large packets.
REM      Then blk_size can cut an 11.5 MiB kernel from ~21800
REM      packets to ~190, which should fix the USB drop-out.
REM   timeout / usb_send failed -> FDL1 rejects large packets.
REM      Stay on 528-byte packets and use 1 MiB chunking instead.
REM
REM Recovery: press RESET or replug USB. Nothing was written.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo FDL1 blk_size probe: 100 KiB at 0x80080000 with 62 KiB packets
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1-ram-probe.bin 0x28007000 ^
  blk_size 63488 ^
  fdl probe\probe100k.bin 0x80080000 ^
  reset
echo.
echo Check the log above for timeout / usb_send failed.
pause
