# Image format 1

An image is what is written at the base of a slot: a 512 byte header followed
by the payload.

All integers are 32 bits, unsigned, little-endian (least significant byte first).

| Offset | Size | Field | Meaning |
|---:|---:|---|---|
| 0 | 4 | magic | the bytes `41 4E 43 48`, "ANCH" |
| 4 | 4 | format | `1`, the version of this table |
| 8 | 4 | device id | the device this image is built for |
| 12 | 4 | version | firmware version, a number that only goes up |
| 16 | 4 | payload size | in bytes |
| 20 | 4 | load address | where the payload must sit in flash |
| 24 | 32 | payload digest | SHA-256 of the payload bytes |
| 56 | 64 | signature | Ed25519 signature of bytes 0 to 55 |
| 120 | 392 | padding | `FF` |
| 512 | payload size | payload | the program, vector table first |

## Why 512 bytes

A Cortex-M vector table must start at an address that is a multiple of its own
size rounded up to a power of two. On this chip that is 512. The slot base is a
multiple of 512, so the header must be too.

## Who reads and writes it

| Side | File |
|---|---|
| writes it (laptop) | `tools/anchor_image.py`, function `make_header` |
| reads it (device) | `src/core/anchor-manifest.adb`, procedure `Parse` |

This format is a starting point, not a standard to respect. It is yours to
change. If you do: change both sides and this table together, and bump `format`.

## Look at one

```console
python3 -c "import sys; print(open('build/slot_a.img','rb').read(120).hex(' ', 4))"
```

Find the magic, the version, the size. Then compare the digest field with:

```console
python3 -c "import hashlib; print(hashlib.sha256(open('build/slot_a.img','rb').read()[512:]).hexdigest())"
```
