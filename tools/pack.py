#!/usr/bin/env python3
"""Turn a built application into a signed image for a slot.

    python3 tools/pack.py                       # bin/hello_a -> build/slot_a.img, version 1
    python3 tools/pack.py --version 2
    python3 tools/pack.py --slot b --version 2  # needs: alr build -- -XANCHOR_SLOT=b

This script plays the firmware AUTHOR: it owns the private key.
"""

import argparse
import os

import anchor_image as img

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--slot", choices=["a", "b"], default="a")
    parser.add_argument("--version", type=int, default=1,
                        help="firmware version written in the manifest")
    parser.add_argument("--elf", help="default: bin/hello_<slot>")
    parser.add_argument("--key",
                        default=os.path.join(ROOT, "keys", "dev_signing.key"))
    parser.add_argument("--out", help="default: build/slot_<slot>.img")
    args = parser.parse_args()

    elf = args.elf or os.path.join(ROOT, "bin", f"hello_{args.slot}")
    out = args.out or os.path.join(ROOT, "build", f"slot_{args.slot}.img")

    payload = img.elf_to_binary(elf, img.payload_base(args.slot))
    image = img.make_image(payload, slot=args.slot, version=args.version,
                           signing_key=img.read_key(args.key))

    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(image)

    print(f"{os.path.relpath(out, ROOT)}: slot {args.slot.upper()}, "
          f"version {args.version}, payload {len(payload)} bytes, "
          f"load at 0x{img.SLOT_BASE[args.slot]:08X}")


if __name__ == "__main__":
    main()
