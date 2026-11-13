@echo off
REM ============================================================
REM Interactive FDL1 session (corrected).
REM Launches spd_dump which auto-execs FDL1 and drops you at the
REM "FDL1 >" prompt. NO standalone exec in this launcher - an exec
REM with no stage-2 downloaded makes FDL1 hang and times out.
REM
REM At the FDL1 > prompt, type these lines IN THIS ORDER (stub last):
REM   fdl stock-kernel.bin 0x80080000
REM   fdl x03-minimal-nopsci.dtb 0x85000000
REM   fdl x03-minimal-initramfs.cpio.gz 0x86000000
REM   fdl booter-stub.bin 0x9efffe00
REM   exec
REM (paths relative to fdl-verification; the kernel upload takes
REM  minutes - do not interrupt; after exec, tool timeout noise is
REM  expected because the "FDL2" is now our running kernel)
REM ============================================================
cd /d "%~dp0..\..\fdl-verification"
spd_dump.exe --wait 600 exec_addr 0x3f28 fdl fdl1-ram-probe.bin 0x28007000
pause
