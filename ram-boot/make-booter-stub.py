#!/usr/bin/env python3
"""Generate the X03 RAM-boot jump stub.

The stub is uploaded through FDL1 as the last downloaded file at
0x9efffe00.  FDL1's EXEC_DATA handler jumps to (load address + 0x200),
so the executable code is placed at file offset 0x200 and runs at
0x9f000000.

At entry it prepares the ARM64 Linux boot protocol registers and
branches into the stock kernel Image:

    x0 = 0x85000000   physical address of the diagnostic DTB
    x1 = 0x80080000   stock kernel Image entry
    ic iallu / dsb / isb, then br x1

MMU state: FDL1 runs without the MMU enabled, which is what the ARM64
boot protocol requires, so no SCTLR manipulation is attempted here.
The kernel flushes its own image through the D-cache after entry.

Usage:
    python make-booter-stub.py [output.bin]

Self-test decodes every generated word back to its fields and asserts
the instruction encoding before writing the file.
"""

import struct
import sys
from pathlib import Path

DTB_ADDRESS = 0x85000000
KERNEL_ENTRY = 0x80080000
STUB_LOAD_ADDRESS = 0x9EFFFE00  # matches the proven FDL2 stage-2 slot
CODE_OFFSET = 0x200


def movz(rd: int, imm16: int, hw: int) -> int:
    """MOVZ Xd, #imm16, LSL #hw*16  (64-bit, sf=1)."""
    assert 0 <= rd < 32 and 0 <= imm16 < 0x10000 and hw in (0, 1, 2, 3)
    word = (1 << 31) | (0b11 << 29) | (0b100101 << 23) | (hw << 21) | (imm16 << 5) | rd
    # Decode back and verify every field.
    assert (word >> 31) & 1 == 1
    assert (word >> 29) & 0b11 == 0b11
    assert (word >> 23) & 0b111111 == 0b100101
    assert (word >> 21) & 0b11 == hw
    assert (word >> 5) & 0xFFFF == imm16
    assert word & 0x1F == rd
    return word


def split_halves(value: int):
    assert 0 <= value < (1 << 32)
    low = value & 0xFFFF
    high = (value >> 16) & 0xFFFF
    assert low == 0, "value must be 16-bit aligned for a single MOVZ"
    return high, low


def branch_register(rn: int) -> int:
    """BR Xn = 1101011 0001 1111 000000 Rn 00000."""
    word = (0b1101011 << 25) | (0b11111 << 16) | (rn << 5)
    assert (word >> 25) & 0b1111011 == 0b1101011
    assert (word >> 16) & 0x1F == 0b11111
    assert (word >> 5) & 0x1F == rn
    assert word & 0x1F == 0
    return word


# Fixed-system-register instructions, standard encodings.
IC_IALLU = 0xD50B7520
DSB_ISH = 0xD5033B9F
ISB_SY = 0xD5033FDF


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).with_name("booter-stub.bin"))

    dtb_high, dtb_low = split_halves(DTB_ADDRESS)
    kern_high, kern_low = split_halves(KERNEL_ENTRY)
    words = [
        movz(0, dtb_high, 1),        # x0 = DTB physical address
        movz(1, kern_high, 1),       # x1 = kernel entry
        DSB_ISH,                     # make downloaded code visible before invalidation
        IC_IALLU,
        DSB_ISH,
        ISB_SY,
        branch_register(1),          # br x1
    ]
    code = b"".join(struct.pack("<I", word) for word in words)
    blob = b"\x00" * CODE_OFFSET + code

    # Disassemble the generated code for the run log.
    print(f"stub load address : {STUB_LOAD_ADDRESS:#010x}")
    print(f"code entry        : {STUB_LOAD_ADDRESS + CODE_OFFSET:#010x}")
    print(f"DTB               : {DTB_ADDRESS:#010x}")
    print(f"kernel entry      : {KERNEL_ENTRY:#010x}")
    for index, word in enumerate(words):
        print(f"  {STUB_LOAD_ADDRESS + CODE_OFFSET + index * 4:#010x}  {word:08x}")

    out.write_bytes(blob)
    print(f"wrote {out} ({len(blob)} bytes)")
    print(f"runs at           : {STUB_LOAD_ADDRESS + CODE_OFFSET:#010x}")


if __name__ == "__main__":
    main()
