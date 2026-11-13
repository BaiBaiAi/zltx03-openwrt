# Detached mega-boot driver v2 (.NET Process.Start to avoid the
# Start-Process Path/PATH dictionary bug).
$base = 'C:\Users\Administrator\Documents\cursor\zltx03\fdl-verification'
$rb   = 'C:\Users\Administrator\Documents\cursor\zltx03\zltx03-openwrt\ram-boot'

$seq = 'exec_addr 0x3f28 ' +
    'fdl fdl1-ram-probe.bin 0x28007000 ' +
    'fdl upload-chunks\k00.bin 0x80080000 ' +
    'fdl upload-chunks\k01.bin 0x80180000 ' +
    'fdl upload-chunks\k02.bin 0x80280000 ' +
    'fdl upload-chunks\k03.bin 0x80380000 ' +
    'fdl upload-chunks\k04.bin 0x80480000 ' +
    'fdl upload-chunks\k05.bin 0x80580000 ' +
    'fdl upload-chunks\k06.bin 0x80680000 ' +
    'fdl upload-chunks\k07.bin 0x80780000 ' +
    'fdl upload-chunks\k08.bin 0x80880000 ' +
    'fdl upload-chunks\k09.bin 0x80980000 ' +
    'fdl upload-chunks\k10.bin 0x80a80000 ' +
    'fdl x03-minimal-nopsci.dtb 0x85000000 ' +
    'fdl x03-minimal-initramfs.cpio.gz 0x86000000 ' +
    'fdl booter-stub.bin 0x9efffe00 exec'

Set-Location $base
$stamp = Get-Date -Format 'HHmmss'
$megaLog = "$rb\mega-$stamp.log"
$megaErr = "$rb\mega-$stamp.err.log"
$watchLog = "$rb\watch-$stamp.log"
$watchErr = "$rb\watch-$stamp.err.log"

function Start-Detached($exe, $argline) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:ComSpec"
    $psi.Arguments = "/c `"`"$exe`" $argline`""
    $psi.WorkingDirectory = $base
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}

Start-Detached "$base\spd_dump.exe" "--wait 600 $seq > `"$megaLog`" 2> `"$megaErr`""
Start-Detached "powershell" "-ExecutionPolicy Bypass -File `"C:\Users\Administrator\Documents\cursor\zltx03\zltx03-openwrt\diagnostics\watch-initramfs-usb.ps1`" -TimeoutSeconds 900 > `"$watchLog`" 2> `"$watchErr`""

Write-Output "Launched detached. Logs: $megaLog / $watchLog"
Write-Output 'Now: power off the device, hold RESET, plug USB.'
