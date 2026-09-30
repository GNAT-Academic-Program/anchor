"""The Anchor image format, host side.

An image is what sits in a flash slot:

    header (512 bytes) = manifest fields + signature + padding
    payload            = the program, vector table first

The layout is documented in docs/IMAGE_FORMAT.md and decoded on the device
by src/core/anchor-manifest.adb. If you change one side, change the other.
"""

import hashlib
import struct

import ed25519

# --- Flash map. Keep in sync with ld/anchor-flash.ld and src/core/anchor-layout.ads.
SLOT_BASE = {"a": 0x08040000, "b": 0x08080000}
SLOT_SIZE = 0x40000
HEADER_SIZE = 0x200
MAX_PAYLOAD_SIZE = SLOT_SIZE - HEADER_SIZE

# --- Manifest, format 1.
MAGIC = b"ANCH"
FORMAT = 1
DEVICE_ID = 0xF7460001          # keep in sync with src/core/anchor-device.ads
FIELDS = struct.Struct("<4sIIIII32s")   # magic .. payload digest
SIGNED_LENGTH = FIELDS.size             # 56: the signature covers these bytes
SIGNATURE_SIZE = 64
PADDING = 0xFF                          # what erased flash looks like

assert SIGNED_LENGTH == 56


def payload_base(slot):
    return SLOT_BASE[slot] + HEADER_SIZE


def elf_to_binary(elf_path, base):
    """Flat memory image of an ELF file, starting at address `base`.

    Same result as `arm-eabi-objcopy -O binary`, without needing the
    toolchain on the PATH. Each loadable segment is copied to its load
    address (p_paddr). Only what is needed for a 32-bit little-endian
    ARM executable is handled.
    """
    with open(elf_path, "rb") as f:
        elf = f.read()

    if elf[:4] != b"\x7fELF" or elf[4] != 1 or elf[5] != 1:
        raise ValueError(f"{elf_path}: not a 32-bit little-endian ELF file")

    e_phoff, = struct.unpack_from("<I", elf, 0x1C)
    e_phentsize, e_phnum = struct.unpack_from("<HH", elf, 0x2A)

    PT_LOAD = 1
    out = bytearray()
    for i in range(e_phnum):
        p_type, p_offset, _vaddr, p_paddr, p_filesz = struct.unpack_from(
            "<IIIII", elf, e_phoff + i * e_phentsize)
        if p_type != PT_LOAD or p_filesz == 0:
            continue
        if p_paddr + p_filesz <= base:
            continue
        if p_paddr < base:
            # The linker may start the first segment a little early so it
            # also covers the ELF file header. Those bytes are not program.
            skip = base - p_paddr
            p_offset, p_paddr, p_filesz = p_offset + skip, base, p_filesz - skip
        start = p_paddr - base
        end = start + p_filesz
        if end > len(out):
            out.extend(bytes([PADDING]) * (end - len(out)))
        out[start:end] = elf[p_offset:p_offset + p_filesz]
    return bytes(out)


def make_header(payload, *, slot, version, signing_key,
                device_id=DEVICE_ID, load_address=None, payload_size=None,
                digest=None):
    """Build the 512 byte header for `payload` and sign it.

    The keyword overrides (load_address, payload_size, digest) exist so
    that attack tools can produce headers that lie, yet carry a valid
    signature. An honest packer never uses them.
    """
    fields = FIELDS.pack(
        MAGIC,
        FORMAT,
        device_id,
        version,
        len(payload) if payload_size is None else payload_size,
        payload_base(slot) if load_address is None else load_address,
        hashlib.sha256(payload).digest() if digest is None else digest)
    signature = ed25519.sign(signing_key, fields)
    header = fields + signature
    return header + bytes([PADDING]) * (HEADER_SIZE - len(header))


def make_image(payload, **header_args):
    """header + payload, ready to be written at the base of a slot."""
    if len(payload) > MAX_PAYLOAD_SIZE:
        raise ValueError("payload does not fit in a slot")
    return make_header(payload, **header_args) + payload


def split_image(image):
    """(header fields as a dict, signature, payload) of an image."""
    magic, fmt, device_id, version, size, load, digest = FIELDS.unpack_from(image)
    fields = dict(magic=magic, format=fmt, device_id=device_id,
                  version=version, payload_size=size, load_address=load,
                  digest=digest)
    signature = image[SIGNED_LENGTH:SIGNED_LENGTH + SIGNATURE_SIZE]
    return fields, signature, image[HEADER_SIZE:]


def read_key(path):
    """32-byte secret key from a text file holding 64 hex digits."""
    with open(path) as f:
        text = "".join(line.split("#")[0] for line in f).strip()
    key = bytes.fromhex(text)
    if len(key) != 32:
        raise ValueError(f"{path}: expected 32 bytes (64 hex digits)")
    return key
