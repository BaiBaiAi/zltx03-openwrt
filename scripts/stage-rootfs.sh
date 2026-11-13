#!/bin/bash
# Stage the X03 userspace for both local and CI packing.
set -eu

SOURCE=$1
DEST=$2
REPO=$(cd "$(dirname "$0")/.." && pwd)

if [ -n "${ZLTX03_SSH_PUBLIC_KEY:-}" ]; then
    ssh-keygen -l -f "$ZLTX03_SSH_PUBLIC_KEY" >/dev/null
fi

rm -rf -- "$DEST"
cp -a -- "$SOURCE" "$DEST"
rm -rf -- "$DEST/lib/modules"
cp -a -- "$REPO/rootfs/." "$DEST/"
chmod 0755 "$DEST/etc/init.d/zltx03-usb"
mkdir -p "$DEST/etc/rc.d"
ln -sfn ../init.d/zltx03-usb "$DEST/etc/rc.d/S18zltx03-usb"
# First-boot management uses SSH keys. Keep LuCI available for later setup.
rm -f -- "$DEST"/etc/rc.d/S[0-9][0-9]uhttpd

if [ -n "${ZLTX03_SSH_PUBLIC_KEY:-}" ]; then
    install -D -m 0600 "$ZLTX03_SSH_PUBLIC_KEY" "$DEST/etc/dropbear/authorized_keys"
fi
