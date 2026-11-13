@echo off
REM ============================================================
REM X03 RAM boot test B: full OpenWrt userspace as initramfs
REM v2 (corrected): the standalone "exec" right after FDL1 was
REM REMOVED. fdl fdl1... already auto-EXECs and connects FDL1 in
REM the brom stage; an extra exec with no stage-2 payload makes
REM FDL1 hang and hit the 15s recv_msg_timeout. The ONLY exec is
REM the final one, after the booter stub has been uploaded.
REM No partition is written. Recovery = press RESET / replug USB.
REM
REM Step 1: enter download mode: power off completely, hold RESET,
REM         plug in USB (BootROM "SPRD U2S Diag" appears).
REM Step 2: run this script.
REM Step 3: Windows RNDIS should enumerate. Set the RNDIS adapter to
REM         192.168.10.2/24, then: ssh root@192.168.10.1
REM         (Dropbear binds the USB interface; pubkey from
REM         ZLTX03_SSH_PUBLIC_KEY at pack time)
REM
REM Note: DTB has /psci removed, so Linux runs on CPU0 only.
REM The modem is NOT initialized in this path (no SML/trustos):
REM NR uplink is out of scope for this test.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo Uploading: kernel + no-psci DTB + OpenWrt initramfs + booter stub (RAM only)
spd_dump.exe --wait 600 exec_addr 0x3f28 ^
  fdl fdl1-ram-probe.bin 0x28007000 ^
  fdl stock-kernel.bin 0x80080000 ^
  fdl "%~dp0x03-openwrt-nopsci.dtb" 0x85000000 ^
  fdl "%~dp0..\..\firmware\dist\x03-openwrt-initramfs.cpio.gz" 0x86000000 ^
  fdl "%~dp0booter-stub.bin" 0x9efffe00 ^
  exec
echo.
echo Watch for RNDIS enumeration, then: ssh root@192.168.10.1
pause
