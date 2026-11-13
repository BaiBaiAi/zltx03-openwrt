param(
    [ValidateRange(1, 1800)]
    [int]$TimeoutSeconds = 90
)

$marker = 'ZLT X03 initramfs: reached PID 1, USB serial ready'
$devicePrefix = 'USB\VID_1782&PID_000B\'
$serialPrefix = 'USB\VID_1782&PID_000B&MI_00\'
$clock = [System.Diagnostics.Stopwatch]::StartNew()
$enumerated = $false
$reportedPort = $null
$serial = $null
$buffer = ''

try {
    while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if (-not $serial) {
            $devices = @(Get-PnpDevice -PresentOnly -InstanceId 'USB\VID_1782&PID_000B*' -ErrorAction SilentlyContinue)
            if (-not $enumerated -and ($devices.InstanceId -like "$devicePrefix*" -or $devices.InstanceId -like "$serialPrefix*")) {
                $enumerated = $true
                Write-Host 'Detected USB device 1782:000b.'
            }
            $portDevice = $devices | Where-Object {
                $_.InstanceId -like "$serialPrefix*" -and $_.Status -eq 'OK'
            } | Select-Object -First 1

            if ($portDevice.FriendlyName -match '\((COM\d+)\)$') {
                $portName = $Matches[1]
                $candidate = [System.IO.Ports.SerialPort]::new($portName, 115200, 'None', 8, 'One')
                $candidate.DtrEnable = $true
                try {
                    $candidate.Open()
                    $serial = $candidate
                    if ($reportedPort -ne $portName) {
                        Write-Host "Reading diagnostic serial on $portName."
                        $reportedPort = $portName
                    }
                } catch {
                    $candidate.Dispose()
                }
            }
        }

        if ($serial) {
            try {
                $buffer += $serial.ReadExisting()
                if ($buffer.Contains($marker)) {
                    Write-Output $marker
                    exit 0
                }
                if ($buffer.Length -ge $marker.Length) {
                    $buffer = $buffer.Substring($buffer.Length - $marker.Length + 1)
                }
            } catch {
                $serial.Dispose()
                $serial = $null
                $buffer = ''
            }
        }
        Start-Sleep -Milliseconds 300
    }
} finally {
    if ($serial) { $serial.Dispose() }
}

if ($enumerated) {
    Write-Output 'USB device 1782:000b appeared. No PID 1 serial marker was received before timeout.'
    exit 2
}
Write-Output 'USB device 1782:000b did not appear before timeout.'
exit 3
