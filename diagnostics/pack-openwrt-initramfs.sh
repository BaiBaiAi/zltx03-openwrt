#!/bin/bash
set -euo pipefail

SOURCE=${1:?Pass the assembled OpenWrt root-sprd directory}
IMAGE=${2:?Pass the initramfs output path}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
ROOT="$WORK/root"

test -x "$SOURCE/sbin/init"
test -x "$SOURCE/sbin/ubusd"
bash "$HERE/../scripts/stage-rootfs.sh" "$SOURCE" "$ROOT"
install -d "$ROOT/dev"
if [ ! -e "$ROOT/dev/console" ]; then
    mknod -m 0600 "$ROOT/dev/console" c 5 1
fi
if [ ! -e "$ROOT/dev/null" ]; then
    mknod -m 0666 "$ROOT/dev/null" c 1 3
fi
if [ ! -e "$ROOT/dev/kmsg" ]; then
    mknod -m 0600 "$ROOT/dev/kmsg" c 1 11
fi

cat > "$ROOT/init" <<'EOF'
#!/bin/sh
if [ ! -t 0 ]; then exec </dev/null; fi
if [ ! -t 1 ]; then exec >/dev/null; fi
if [ ! -t 2 ]; then exec 2>/dev/null; fi
printf '<6>ZLT X03 RAM OpenWrt: starting /sbin/init\n' >/dev/kmsg || :
export INITRAMFS=1
exec /sbin/init
EOF
chmod 0755 "$ROOT/init"

(
    cd "$ROOT"
    find . -print0 | LC_ALL=C sort -z | cpio --null --quiet -o -H newc --owner 0:0
) | gzip -n > "$WORK/openwrt.cpio.gz"
install -m 0644 "$WORK/openwrt.cpio.gz" "$IMAGE"
