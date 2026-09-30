#!/usr/bin/env python3
"""Turn a good image into hostile ones.

    python3 tools/attack.py            # build/slot_a.img -> build/attacks/*.img
    python3 tools/attack.py --list

This script plays the ADVERSARY. Each attack is a small function that
takes the good image and returns a bad one. The bootloader must refuse
every one of them; tests/gauntlet.robot checks that it does.

Adding an attack: write a function, decorate it with @attack, then add a
test line in tests/gauntlet.robot.
"""

import argparse
import os
import struct

import anchor_image as img

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ATTACKS = {}


def attack(function):
    ATTACKS[function.__name__] = function
    return function


def _patch_u32(image, offset, value):
    out = bytearray(image)
    struct.pack_into("<I", out, offset, value)
    return bytes(out)


# An attacker can make a key pair too. It is just not the one the device trusts.
ATTACKER_KEY = bytes(range(32))


@attack
def bad_magic(image, key):
    """The header does not even start with "ANCH"."""
    return b"\x00\x00\x00\x00" + image[4:]


@attack
def flipped_payload_bit(image, key):
    """One bit of the program changed in transit. Header untouched."""
    out = bytearray(image)
    out[img.HEADER_SIZE + 0x400] ^= 0x01
    return bytes(out)


@attack
def unsigned(image, key):
    """Correct manifest and digest, but the signature is all zeros."""
    start = img.SIGNED_LENGTH
    return image[:start] + bytes(img.SIGNATURE_SIZE) + image[start + img.SIGNATURE_SIZE:]


@attack
def wrong_key(image, key):
    """A complete, well-formed image, signed by the attacker's own key."""
    fields, _, payload = img.split_image(image)
    return img.make_image(payload, slot="a", version=fields["version"],
                          signing_key=ATTACKER_KEY)


@attack
def edited_version(image, key):
    """Version field bumped to 99 after signing, to look newer."""
    return _patch_u32(image, 12, 99)


@attack
def size_overflow(image, key):
    """Payload size field says 4 GiB. Will the bootloader read that far?"""
    return _patch_u32(image, 16, 0xFFFFFFFF)


@attack
def wrong_device(image, key):
    """Genuinely signed by the vendor, but built for another product."""
    fields, _, payload = img.split_image(image)
    return img.make_image(payload, slot="a", version=fields["version"],
                          signing_key=key, device_id=0x0BAD0001)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--image",
                        default=os.path.join(ROOT, "build", "slot_a.img"))
    parser.add_argument("--key",
                        default=os.path.join(ROOT, "keys", "dev_signing.key"))
    parser.add_argument("--out", default=os.path.join(ROOT, "build", "attacks"))
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        for name, function in ATTACKS.items():
            print(f"{name:22} {function.__doc__}")
        return

    with open(args.image, "rb") as f:
        good = f.read()
    key = img.read_key(args.key)

    os.makedirs(args.out, exist_ok=True)
    for name, function in ATTACKS.items():
        bad = function(good, key)
        assert bad != good, f"{name} did not change the image"
        with open(os.path.join(args.out, name + ".img"), "wb") as f:
            f.write(bad)
        print(f"build/attacks/{name}.img")


if __name__ == "__main__":
    main()
