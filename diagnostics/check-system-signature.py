#!/usr/bin/env python3
"""Check the ZLT X03 system trailer against a trusted stock dump."""

import argparse
import hashlib
import struct
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa


def check_image(image):
    if len(image) < 48 or image[:4] != b"\x31\x18\x10\x06":
        raise ValueError("missing UBIFS superblock")
    min_io, leb_size, leb_count, _ = struct.unpack_from("<IIII", image, 32)
    if (min_io, leb_size) != (2048, 126976) or not leb_count:
        raise ValueError("unexpected X03 UBIFS geometry")
    payload_end = leb_size * leb_count
    trailer = image[payload_end:]
    if len(trailer) < 0x494 or trailer[0x294:0x298] != b"DHTB":
        raise ValueError(f"missing DHTB trailer at {payload_end + 0x294:#x}")
    if struct.unpack_from("<I", trailer, 0x2C4)[0] != payload_end:
        raise ValueError("DHTB payload length disagrees with the superblock")

    certificate = trailer[0x60:0x294]
    if struct.unpack_from("<II", certificate) != (0, 2048):
        raise ValueError("unsupported X03 certificate type or key size")
    public_key = certificate[4:0x10C]
    exponent = int.from_bytes(certificate[8:12], "big")
    modulus = int.from_bytes(certificate[12:0x10C], "big")
    if exponent != 65537 or modulus.bit_length() != 2048:
        raise ValueError("invalid X03 RSA public key")
    data_hash = hashlib.sha256(memoryview(image)[:payload_end]).digest()
    if certificate[0x10C:0x12C] != data_hash:
        raise ValueError("UBIFS SHA-256 differs from the certificate")

    key = rsa.RSAPublicNumbers(exponent, modulus).public_key()
    key.verify(
        certificate[0x134:],
        certificate[0x10C:0x134],
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.AUTO),
        hashes.SHA256(),
    )
    return public_key, payload_end


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--stock", type=Path, required=True, help="known-good X03 system dump")
    args = parser.parse_args()
    try:
        stock_key, _ = check_image(args.stock.read_bytes())
        image_key, size = check_image(args.image.read_bytes())
        if image_key != stock_key:
            raise ValueError("RSA public key differs from the stock certificate")
    except (OSError, ValueError) as error:
        parser.exit(1, f"FAIL: {error}\n")
    except InvalidSignature:
        parser.exit(1, "FAIL: RSA-PSS certificate signature mismatch\n")
    print(f"OK: {size:#x} bytes, payload SHA-256 and RSA-PSS match stock key")


if __name__ == "__main__":
    main()
