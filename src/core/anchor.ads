--  Anchor: a SPARK bootloader that only runs firmware it can vouch for.
--
--  This root package holds the few basic types everything else shares.
--  Start reading in ARCHITECTURE.md, then src/boot/anchor_main.adb.

with Interfaces;

package Anchor with
  Pure,
  SPARK_Mode
is

   subtype Byte is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;

   type Byte_Array is array (Natural range <>) of Byte;

end Anchor;
