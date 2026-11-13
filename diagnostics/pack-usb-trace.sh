#!/bin/bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SOURCE=${1:?Pass the staged X03 root directory}
IMAGE=${2:?Pass the diagnostic output image path}
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT

test -x "$SOURCE/sbin/init"
cp -a -- "$SOURCE" "$WORK/root"
ROOT="$WORK/root"
mv "$ROOT/sbin/init" "$ROOT/sbin/openwrt-init"
install -m 0755 "$HERE/usb-boot-init.sh" "$ROOT/sbin/init"
# The diagnostic gadget owns the same USB controller throughout this boot.
rm -f -- "$ROOT/etc/rc.d/S18zltx03-usb"
mkfs.ubifs -m 2048 -e 126976 -c 285 -x zlib -r "$ROOT" -o "$WORK/system.ubifs"
install -m 0644 "$WORK/system.ubifs" "$IMAGE"
