#!/bin/bash
# Clone a prepared X03 diagnostic DTB and remove the /psci node for RAM boot.
#
# The RAM boot path enters the kernel directly from FDL1 without running the
# stock SML, so there is no EL3 PSCI implementation.  With /psci removed the
# stock 4.14 kernel boots on CPU0 and simply never onlines the other cores.
#
# Usage (run inside WSL):
#   bash make-nopsci-dtb.sh <kernel-Image> <src.dtb> <initramfs.cpio.gz> <out.dtb>
#
# <src.dtb> must be a DTB already prepared by diagnostics/prepare-initramfs-dtb.sh
# (initrd range and rdinit set).  Removing /psci only shrinks the blob, so the
# layout check is re-run against the result.

set -euo pipefail

KERNEL=${1:?Pass the stock kernel Image}
SRC=${2:?Pass the prepared source DTB}
INITRAMFS=${3:?Pass the initramfs archive}
OUT=${4:?Pass the output DTB path}

HERE=$(cd "$(dirname "$0")" && pwd)
CHECK="$HERE/../diagnostics/check-initramfs-layout.py"

if [ -e "$OUT" ] && [ "$SRC" -ef "$OUT" ]; then
    printf '%s\n' 'Use a separate output path for the no-psci DTB.' >&2
    exit 1
fi
if fdtget "$SRC" /psci method >/dev/null 2>&1; then
    cp -- "$SRC" "$OUT"
    fdtput -r "$OUT" /psci
    if fdtget "$OUT" /psci method >/dev/null 2>&1; then
        printf '%s\n' 'fdtput -r failed to remove /psci.' >&2
        exit 1
    fi
    printf 'Removed /psci from %s (%s -> %s bytes)\n' \
        "$(basename "$SRC")" "$(stat -c %s "$SRC")" "$(stat -c %s "$OUT")"
else
    printf '%s already has no /psci node, copying as-is.\n' "$(basename "$SRC")"
    cp -- "$SRC" "$OUT"
fi

python3 "$CHECK" "$KERNEL" "$OUT" "$INITRAMFS"
printf 'wrote %s\n' "$OUT"
