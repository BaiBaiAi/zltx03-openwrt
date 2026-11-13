#!/bin/sh
# Diagnostic PID 1 wrapper. The device still boots OpenWrt's real init.
export PATH=/sbin:/bin:/usr/sbin:/usr/bin

start_usb_trace() {
	local configfs=/sys/kernel/config
	local gadget="$configfs/usb_gadget/zltx03-trace"
	local config="$gadget/configs/b.1"
	local udc=29100000.dwc3
	local trace="$gadget/functions/gser.gs2"
	local second="$gadget/functions/gser.gs3"
	local attempts=10

	while [ ! -d "/sys/class/udc/$udc" ] && [ "$attempts" -gt 0 ]; do
		sleep 1
		attempts=$((attempts - 1))
	done
	[ -d "/sys/class/udc/$udc" ] || return 1
	[ -d "$configfs/usb_gadget" ] || mount -t configfs configfs "$configfs" || return 1
	mkdir -p "$gadget/strings/0x409" "$config" "$trace" "$second" || return 1
	printf '0x1782\n' > "$gadget/idVendor" &&
	printf '0x000b\n' > "$gadget/idProduct" &&
	printf '0x0405\n' > "$gadget/bcdDevice" &&
	printf 'ZLT X03 boot diagnostics\n' > "$gadget/strings/0x409/product" &&
	printf '500\n' > "$config/MaxPower" &&
	printf '0xc0\n' > "$config/bmAttributes" || return 1
	# The stock INF matches calibration-mode MI_00 as SPRD AT.
	ln -s "$trace" "$config/f1" &&
	ln -s "$second" "$config/f2" &&
	printf '%s\n' "$udc" > "$gadget/UDC" || return 1
	trace_port=$(cat "$trace/port_num") || return 1
}

send_usb_trace() {
	local tty="ttyGS$trace_port"
	local numbers
	local attempts=30
	read -r numbers < "/sys/class/tty/$tty/dev" || return 1
	# Procd remounts /dev. Use a temporary node on /tmp after its mount.
	until grep -q ' /tmp tmpfs ' /proc/mounts; do
		[ "$attempts" -gt 0 ] || return 1
		sleep 1
		attempts=$((attempts - 1))
	done
	mknod /tmp/zltx03-trace-tty c "${numbers%:*}" "${numbers#*:}" || return 1
	while :; do
		{
			printf '\nZLT X03 reached diagnostic PID 1\n'
			dmesg
			printf '\n--- mounts ---\n'
			cat /proc/mounts
			printf '\n--- processes ---\n'
			ps
		} > /tmp/zltx03-trace-tty 2>/dev/null
		sleep 4
	done
}

mount -t proc proc /proc
mount -t sysfs sysfs /sys
if start_usb_trace; then send_usb_trace & fi
exec /sbin/openwrt-init "$@"
