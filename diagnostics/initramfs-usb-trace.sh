#!/bin/sh

trace_fail() {
	printf '<4>ZLT X03 USB trace: %s\n' "$*" > /dev/kmsg 2>/dev/null || :
	exit 1
}

configfs=/sys/kernel/config
gadget="$configfs/usb_gadget/zltx03-initramfs"
config="$gadget/configs/b.1"
udc=29100000.dwc3
attempts=15
while [ ! -d "/sys/class/udc/$udc" ]; do
	[ "$attempts" -gt 0 ] || trace_fail "UDC $udc did not appear"
	busybox sleep 1
	attempts=$((attempts - 1))
done

[ -d "$configfs/usb_gadget" ] ||
	busybox mount -t configfs none "$configfs" ||
	trace_fail "could not mount configfs"

busybox mkdir -p "$gadget/strings/0x409" "$config/strings/0x409" ||
	trace_fail "could not create gadget"
printf '0x1782\n' > "$gadget/idVendor" &&
printf '0x000b\n' > "$gadget/idProduct" &&
printf '0x0404\n' > "$gadget/bcdDevice" &&
printf 'ZLT X03 initramfs diagnostics\n' > "$gadget/strings/0x409/product" &&
printf 'X03-INITRAMFS\n' > "$gadget/strings/0x409/serialnumber" &&
printf 'Diagnostics\n' > "$config/strings/0x409/configuration" &&
printf '500\n' > "$config/MaxPower" &&
printf '0xc0\n' > "$config/bmAttributes" ||
	trace_fail "could not set USB descriptors"

# Match the original calibration-mode interface order. MI_00 is SPRD AT.
for function in gser.gs2 vser.gs0 gser.gs3 gser.gs1; do
	busybox mkdir "$gadget/functions/$function" &&
	busybox ln -s "$gadget/functions/$function" "$config/$function" ||
	trace_fail "could not add $function"
done
printf '%s\n' "$udc" > "$gadget/UDC" || trace_fail "could not bind $udc"
read -r port < "$gadget/functions/gser.gs2/port_num" || trace_fail "no serial port number"
read -r device < "/sys/class/tty/ttyGS$port/dev" || trace_fail "no ttyGS$port device"
busybox mknod -m 0600 /dev/x03-trace c "${device%:*}" "${device#*:}" ||
	trace_fail "could not create trace device"

# A host can open the port after enumeration. Keep publishing the marker.
while :; do
	{
		printf '\nZLT X03 initramfs: reached PID 1, USB serial ready\n'
		busybox uname -a
	} 2>/dev/null > /dev/x03-trace
	busybox sleep 3
done
