/* Flash region of an application that lives in slot B.
 *
 * The first ANCHOR_HEADER_SIZE bytes of the slot hold the image header
 * (manifest + signature). tools/pack.py writes it. The program itself
 * (the "payload") starts right after, vector table first.
 */

INCLUDE anchor-flash.ld

MEMORY
{
  flash  (rx) : ORIGIN = ANCHOR_SLOT_B_BASE + ANCHOR_HEADER_SIZE,
                LENGTH = ANCHOR_SLOT_SIZE - ANCHOR_HEADER_SIZE
}

/* Lets the application find its own header (see apps/hello). */
__anchor_header = ANCHOR_SLOT_B_BASE;

__stack_size = 16K;
