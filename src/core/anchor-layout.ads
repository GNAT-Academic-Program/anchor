--  Where things live in flash.
--
--  The same numbers exist in ld/anchor-flash.ld (for the linker) and in
--  tools/anchor_image.py (for the host tools). Keep the three in sync.
--
--     address      size      content
--     0x08000000   128 KiB   bootloader
--     0x08020000   128 KiB   metadata copy 0   (reserved, unused in the seed)
--     0x08040000   256 KiB   slot A = header + payload
--     0x08080000   256 KiB   slot B = header + payload
--     0x080C0000   256 KiB   metadata copy 1   (reserved, unused in the seed)

package Anchor.Layout with
  Pure,
  SPARK_Mode
is

   use type U32;

   type Slot_Id is (A, B);

   Slot_Size   : constant := 16#4_0000#;   --  256 KiB
   Header_Size : constant := 16#200#;      --  512 bytes

   Max_Payload_Size : constant := Slot_Size - Header_Size;

   function Slot_Base (S : Slot_Id) return U32 is
     (case S is
         when A => 16#0804_0000#,
         when B => 16#0808_0000#);

   --  The payload (the program itself) starts right after the header.
   --  Its first 8 bytes are the Cortex-M vector table entries the jump
   --  needs: initial stack pointer, then reset handler address.
   function Payload_Base (S : Slot_Id) return U32 is
     (Slot_Base (S) + Header_Size);

   --  Reserved for the persistent boot state (active slot, version
   --  counter, trial count...). Two copies in two different erase
   --  sectors, so one can always survive a power cut. Unused in the seed.
   Metadata_0_Base : constant U32 := 16#0802_0000#;
   Metadata_1_Base : constant U32 := 16#080C_0000#;

end Anchor.Layout;
