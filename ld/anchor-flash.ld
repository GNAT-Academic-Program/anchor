/* Anchor flash map for the STM32F746NG (1 MiB of flash).
 *
 * This file is the single source of truth for the LINKER.
 * The same numbers exist for the Ada code in src/core/anchor-layout.ads
 * and for the host tools in tools/anchor_image.py. Keep the three in sync.
 *
 *   address      size     flash sector   content
 *   0x08000000   128 KiB  0, 1, 2, 3     bootloader
 *   0x08020000   128 KiB  4              metadata copy 0   (reserved, unused in the seed)
 *   0x08040000   256 KiB  5              slot A  = 512 byte header + payload
 *   0x08080000   256 KiB  6              slot B  = 512 byte header + payload
 *   0x080C0000   256 KiB  7              metadata copy 1   (reserved, unused in the seed)
 *
 * Regions follow the real erase sectors of the chip, so that one region
 * can be erased without touching its neighbours.
 */

ANCHOR_BOOT_BASE   = 0x08000000;
ANCHOR_BOOT_SIZE   = 128K;
ANCHOR_SLOT_A_BASE = 0x08040000;
ANCHOR_SLOT_B_BASE = 0x08080000;
ANCHOR_SLOT_SIZE   = 256K;
ANCHOR_HEADER_SIZE = 0x200;
