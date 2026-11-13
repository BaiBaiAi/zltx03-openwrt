#!/bin/bash
set -euo pipefail

SOURCE=${1:?Pass the staged X03 root directory}
IMAGE=${2:?Pass the initramfs output path}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT

test -x "$SOURCE/bin/busybox"
test -f "$SOURCE/lib/ld-musl-aarch64.so.1"
test -f "$SOURCE/lib/libgcc_s.so.1"
ROOT="$WORK/root"
mkdir -p "$ROOT"/{bin,dev,lib,proc,sys}
install -m 0755 "$SOURCE/bin/busybox" "$ROOT/bin/busybox"
install -m 0755 "$SOURCE/lib/ld-musl-aarch64.so.1" "$ROOT/lib/libc.so"
install -m 0644 "$SOURCE/lib/libgcc_s.so.1" "$ROOT/lib/libgcc_s.so.1"
ln -s libc.so "$ROOT/lib/ld-musl-aarch64.so.1"
ln -s busybox "$ROOT/bin/sh"
install -m 0755 "$HERE/initramfs-usb-trace.sh" "$ROOT/bin/x03-usb-trace"

cat > "$ROOT/init" <<'EOF'
#!/bin/sh
export PATH=/bin
report() {
	printf '%s\n' "$*"
	printf '<6>%s\n' "$*" > /dev/kmsg 2>/dev/null || :
}
report "ZLT X03 initramfs: reached PID $$"
if busybox mount -t proc proc /proc; then
	report "ZLT X03 initramfs: $(busybox uname -m) $(busybox cat /proc/sys/kernel/osrelease)"
else
	report "ZLT X03 initramfs: proc mount failed"
fi
if busybox mount -t sysfs sysfs /sys; then
	report "ZLT X03 initramfs: sysfs mounted"
	if read -r cmdline < /proc/cmdline; then
		case " $cmdline " in
			*" x03_usb_trace=1 "*) /bin/x03-usb-trace & ;;
		esac
	fi
else
	report "ZLT X03 initramfs: sysfs mount failed"
fi
while :; do
	busybox sleep 60
done
EOF
chmod 0755 "$ROOT/init"

# Supply /dev/console even when the kernel has no devtmpfs support.
mknod -m 0600 "$ROOT/dev/console" c 5 1
mknod -m 0600 "$ROOT/dev/kmsg" c 1 11
(
	cd "$ROOT"
	find . -print0 | LC_ALL=C sort -z | cpio --null --quiet -o -H newc --owner 0:0
) | gzip -n > "$WORK/initramfs.cpio.gz"
install -m 0644 "$WORK/initramfs.cpio.gz" "$IMAGE"
