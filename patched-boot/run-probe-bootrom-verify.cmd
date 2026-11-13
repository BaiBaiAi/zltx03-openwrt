@echo off
REM ============================================================
REM PROBE A v2: BootROM behaviour in download mode. ZERO writes.
REM
REM 2026-11-13 REAL RUN: PASSED (FDL1 CONNECTED).
REM   After "EXEC FDL1" the device answered
REM     BSL_REP_VER: "Spreadtrum Boot Block version 1.1"
REM   then CMD_CONNECT FDL1 and KEEP_CHARGE FDL1 both succeeded.
REM   No exec_addr, no custom exec stub, and NO line
REM     "bypassing BROM verification with CVE-2022-38691".
REM
REM WHAT THIS PROVES (confirmed):
REM   BootROM accepted fdl1-ram-probe.bin, whose payload was
REM   modified, with NO host-side bypass at all. Therefore
REM   exec_addr 0x3f28 / custom_exec_no_verify_3f28.bin is NOT
REM   REQUIRED on this device for this FDL1 image.
REM
REM WHAT THIS DOES NOT PROVE (important):
REM   It does NOT settle the secure-boot fuse state. A BootROM that
REM   validates only the certificate and not the payload hash
REM   (CVE-2022-38694 class) behaves the same way whether or not
REM   secure boot is enabled. The NAND SPL boot path still has to
REM   be judged by the P0 experiment (patched SPL actually boots).
REM
REM WHY THE 4 BYTES MATTER (verified offline):
REM   fdl1.bin = DHTB header 0x200, payload 0x200..0xB960,
REM   sprdsignedimageheader @0xB960 with cert_size 0x254 and
REM   cert_offset 0xB9C0. 0x8694 is INSIDE the payload, so the
REM   content hash covered by that cert no longer matches. The
REM   header mPayloadHash is all zero and the cert bytes are
REM   unchanged, so a BootROM checking only the cert accepts it.
REM   The 4 bytes themselves are a BL verify_call (86010094)
REM   replaced by MOV W0,#0 (00008052): they disable FDL1's OWN check of
REM   the second stage, not its own signature.
REM   cert key_size @0xB9C4 = 0x800 (a multiple of 0x800), so
REM   spd_dump.c:869-884 does NOT trigger the auto CVE bypass.
REM
REM v2 CHANGE: the trailing "timeout reached" in the first run
REM   came from the final `reset` being sent while only FDL1 was
REM   loaded (FDL1 does not answer NORMAL_RESET). It is harmless,
REM   but v2 removes `reset` to keep the log clean. The tool does
REM   NOT exit on its own: spd_dump.c:525-575 is a while(1) loop
REM   that enters an interactive prompt (FDL1 here) when the
REM   argument list is consumed. Close the window or press Ctrl+C.
REM
REM Enter download mode: power off fully, hold RESET, plug USB.
REM Power off by hand when done. Nothing is written.
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
echo PROBE A v2: modified-payload FDL1, no exec_addr, no reset
spd_dump.exe --wait 600 fdl fdl1-ram-probe.bin 0x28007000
echo.
echo Expect: CHECK_BAUD FDL1 + "Spreadtrum Boot Block version 1.1".
echo Power off the device by hand. Nothing was written.
pause
