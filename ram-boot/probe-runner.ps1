# X03 FDL1 download probe runner v2.
# Waits for the device before EVERY attempt. Robust failure detection:
# device removed / find port failed / timeout reached / wrong command.
#
# A  : connect patched FDL1, 100KB @0x80080000 (kernel address)
# A2 : escalate 1MB/2MB/4MB in free RAM
# F  : full RAM boot - kernel in 2MiB chunks + DTB + initramfs + stub + exec
# B  : (A failed) reconnect, 100KB @0x9efffe00 (known-good slot)
# C  : (B failed) reconnect, 100KB @0x85000000
param([int]$WaitSeconds = 600)

$ErrorActionPreference = 'Continue'
$base = 'C:\Users\Administrator\Documents\cursor\zltx03\fdl-verification'
$log  = 'C:\Users\Administrator\Documents\cursor\zltx03\zltx03-openwrt\ram-boot\probe-runner.log'
$failPattern = 'device removed|find port failed|timeout reached|unexpected response|wrong command|wrong mode'

function Log($msg) {
    $line = ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg)
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

function Wait-Device($label) {
    Log "Waiting for SPRD U2S Diag ($label): power off, hold RESET, plug USB..."
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-Date) -lt $deadline) {
        $dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object { $_.FriendlyName -match 'SPRD U2S Diag' }
        if ($dev) { Log "Device present: $($dev.FriendlyName)"; return $true }
        Start-Sleep -Milliseconds 800
    }
    Log "Device did not appear within $WaitSeconds s ($label)."
    return $false
}

function Run-Attempt($name, $argline) {
    Log "=== Attempt $name ==="
    Log "spd_dump $argline"
    $tmp = Join-Path $env:TEMP 'spd_dump_out.txt'
    cmd /c "`"$base\spd_dump.exe`" --wait 30 $argline > `"$tmp`" 2>&1"
    $out = [System.IO.File]::ReadAllText($tmp)
    Add-Content -Path $log -Value $out -Encoding utf8
    if ($out -match $failPattern) { Log "RESULT $name : FAILED"; return $false }
    Log "RESULT $name : OK"
    return $true
}

Set-Location $base
Remove-Item $log -ErrorAction SilentlyContinue

if (-not (Wait-Device 'attempt A')) { exit 2 }

if (-not (Run-Attempt 'A' 'exec_addr 0x3f28 fdl fdl1-ram-probe.bin 0x28007000 fdl probe\probe100k.bin 0x80080000')) {
    if (-not (Wait-Device 'attempt B')) { exit 2 }
    if (-not (Run-Attempt 'B' '-r fdl probe\probe100k.bin 0x9efffe00')) {
        if (-not (Wait-Device 'attempt C')) { exit 2 }
        if (-not (Run-Attempt 'C' '-r fdl probe\probe100k.bin 0x85000000')) {
            Log 'CONCLUSION: patched FDL1 download path broken - need stock-FDL1 route'
        } else {
            Log 'CONCLUSION: address-specific rejection (0x80080000 and 0x9efffe00 refused, 0x85000000 ok)'
        }
        exit 1
    }
    Log 'CONCLUSION: 0x9efffe00 accepted, 0x80080000 refused -> address-dependent'
    exit 1
}

if (-not (Run-Attempt 'A2' '-r fdl probe\probe1m.bin 0x80480000 fdl probe\probe2m.bin 0x80680000 fdl probe\probe4m.bin 0x80880000')) {
    Log 'CONCLUSION: size cap below 4MB (see log for which chunk passed)'
    exit 1
}

Log '=== Attempt F: full RAM boot (chunked kernel + exec) ==='
if (-not (Wait-Device 'attempt F')) { exit 2 }
$f = Run-Attempt 'F' ('-r fdl kernel-chunks\k0.bin 0x80080000 fdl kernel-chunks\k1.bin 0x80280000 ' +
    'fdl kernel-chunks\k2.bin 0x80480000 fdl kernel-chunks\k3.bin 0x80680000 ' +
    'fdl kernel-chunks\k4.bin 0x80880000 fdl kernel-chunks\k5.bin 0x80a80000 ' +
    'fdl x03-minimal-nopsci.dtb 0x85000000 fdl x03-minimal-initramfs.cpio.gz 0x86000000 ' +
    'fdl booter-stub.bin 0x9efffe00 exec')
if ($f) {
    Log 'F completed without tool-level failure. If the final exec ACKed, the kernel is booting now.'
} else {
    Log 'F reported failure - check whether it happened after the final exec (expected noise while kernel runs).'
}
Log 'DONE. Verify with: powershell -File zltx03-openwrt\diagnostics\watch-initramfs-usb.ps1 -TimeoutSeconds 120'
