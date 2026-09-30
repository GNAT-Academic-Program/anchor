/* Flash region of the bootloader: first 128 KiB.
 *
 * If the bootloader ever grows past 128 KiB the link FAILS. That is on
 * purpose: it must never spill into the metadata or the slots.
 */

INCLUDE anchor-flash.ld

MEMORY
{
  flash  (rx) : ORIGIN = ANCHOR_BOOT_BASE, LENGTH = ANCHOR_BOOT_SIZE
}

/* The signature check needs more stack than the 4 KiB runtime default. */
__stack_size = 32K;
