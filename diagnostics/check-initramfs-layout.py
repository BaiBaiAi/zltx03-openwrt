#!/usr/bin/env python3
"""Validate the X03 Linux RAM layout against its stock device tree."""

import argparse
import struct
import subprocess
from pathlib import Path


def reg_ranges(dtb, node):
    cells = subprocess.check_output(
        ["fdtget", "-t", "x", str(dtb), node, "reg"], text=True
    ).split()
    if not cells or len(cells) % 4:
        raise ValueError(f"{node}: expected two address cells and two size cells")
    for index in range(0, len(cells), 4):
        high, low, size_high, size_low = (int(cell, 16) for cell in cells[index:index + 4])
        start = (high << 32) | low
        length = (size_high << 32) | size_low
        yield start, start + length


def reserved_ranges(dtb, blob):
    offset = struct.unpack_from(">I", blob, 16)[0]
    while True:
        start, size = struct.unpack_from(">QQ", blob, offset)
        if not (start or size):
            break
        yield "/memreserve/", start, start + size
        offset += 16

    nodes = subprocess.check_output(["fdtget", "-l", str(dtb), "/reserved-memory"], text=True)
    # Treat every declared range as occupied, including disabled nodes.
    for name in nodes.split():
        path = "/reserved-memory/" + name
        for start, end in reg_ranges(dtb, path):
            yield path, start, end


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kernel", type=Path)
    parser.add_argument("dtb", type=Path)
    parser.add_argument("initramfs", type=Path)
    parser.add_argument("--kernel-address", type=lambda value: int(value, 0), default=0x80080000)
    parser.add_argument("--dtb-address", type=lambda value: int(value, 0), default=0x85000000)
    parser.add_argument("--initramfs-address", type=lambda value: int(value, 0), default=0x86000000)
    args = parser.parse_args()

    try:
        image = args.kernel.read_bytes()
        if image[56:60] != b"ARMd":
            raise ValueError("kernel lacks the ARM64 Image magic")
        text_offset, image_size = struct.unpack_from("<QQ", image, 8)
        if not image_size or (args.kernel_address - text_offset) % 0x200000:
            raise ValueError("invalid ARM64 Image size or unaligned Image base")

        dtb = args.dtb.read_bytes()
        magic, size = struct.unpack_from(">II", dtb)
        if magic != 0xD00DFEED or size != len(dtb) or size > 0x200000 or args.dtb_address % 8:
            raise ValueError("invalid DTB size, magic or alignment")
        with args.initramfs.open("rb") as archive:
            if archive.read(3) != b"\x1f\x8b\x08":
                raise ValueError("expected a gzip initramfs")

        ram = list(reg_ranges(args.dtb, "/memory@80000000"))
        reserved = list(reserved_ranges(args.dtb, dtb))
        # The stock kernel can use this address even if the DTB omits magic-addr.
        reserved.append(("stock sysdump magic page", 0x85500000, 0x85501000))
        payloads = [
            ("Image", args.kernel_address, max(image_size, len(image))),
            ("DTB", args.dtb_address, size),
            ("initramfs", args.initramfs_address, args.initramfs.stat().st_size),
        ]
        used = []
        for name, start, length in payloads:
            end = start + length
            if not any(low <= start < end <= high for low, high in ram):
                raise ValueError(f"{name}: range {start:#x}–{end:#x} is outside DDR")
            for other, low, high in reserved + used:
                if start < high and low < end:
                    raise ValueError(f"{name}: range {start:#x}–{end:#x} overlaps {other}")
            used.append((name, start, end))

        window_base = min(args.kernel_address, args.initramfs_address) & ~0x3FFFFFFF
        if max(used[0][2], used[2][2]) > window_base + 0x800000000:
            raise ValueError("Image and initramfs exceed the ARM64 boot window")
    except (OSError, ValueError, struct.error, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Layout check failed: {error}\n")

    for name, start, end in used:
        print(f"{name:<9} {start:#010x}–{end:#010x} ({end - start:#x} bytes, end exclusive)")
    print(f"Checked {len(reserved)} reserved ranges. Static DDR layout passes.")


if __name__ == "__main__":
    main()
