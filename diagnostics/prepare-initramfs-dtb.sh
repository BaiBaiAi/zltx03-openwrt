#!/bin/bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
KERNEL=${1:?Pass the original ARM64 Image}
STOCK_DTB=${2:?Pass the original boot DTB}
INITRAMFS=${3:?Pass the diagnostic initramfs}
OUTPUT=${4:?Pass the output DTB path}
INITRD_START=${5:-0x86000000}
USB_TRACE=${6:-1}
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT

if [ -e "$OUTPUT" ] && [ "$STOCK_DTB" -ef "$OUTPUT" ]; then
    printf '%s\n' 'Use a separate output path for the diagnostic DTB.' >&2
    exit 1
fi
python3 "$HERE/check-initramfs-layout.py" "$KERNEL" "$STOCK_DTB" "$INITRAMFS" \
    --initramfs-address "$INITRD_START"
cp -- "$STOCK_DTB" "$WORK/diagnostic.dtb"
DTB="$WORK/diagnostic.dtb"
INITRD_SIZE=$(stat -c %s -- "$INITRAMFS")
INITRD_END=$((INITRD_START + INITRD_SIZE))

read -r -a stock_args <<< "$(fdtget -t s "$DTB" /chosen bootargs)"
args=()
for arg in "${stock_args[@]}"; do
    case "$arg" in
        init=*|rdinit=*|root=*|rootfstype=*|rootflags=*|rootwait|rootdelay=*|ro|rw|ubi.mtd=*|loglevel=*|x03_usb_trace=*) ;;
        *) args+=("$arg") ;;
    esac
done
args+=(rdinit=/init loglevel=7)
case "$USB_TRACE" in
    1) args+=(x03_usb_trace=1) ;;
    0) ;;
    *) printf '%s\n' 'USB trace must be 0 or 1.' >&2; exit 1 ;;
esac
fdtput -t s "$DTB" /chosen bootargs "${args[*]}"
fdtput -t x "$DTB" /chosen linux,initrd-start 0 "$(printf '%x' "$INITRD_START")"
fdtput -t x "$DTB" /chosen linux,initrd-end 0 "$(printf '%x' "$INITRD_END")"

python3 "$HERE/check-initramfs-layout.py" "$KERNEL" "$DTB" "$INITRAMFS" \
    --initramfs-address "$INITRD_START"
install -m 0644 "$DTB" "$OUTPUT"
