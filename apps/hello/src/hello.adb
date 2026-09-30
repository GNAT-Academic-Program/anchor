--  Demo application: stands in for "the real firmware".
--
--  It says which version it is and where it runs from, then ticks once
--  per second. The tick proves more than it seems: it needs the timer
--  interrupt, so it only works if the bootloader handed over the
--  processor cleanly (vector table, stack, interrupts).

with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;

with Console;

procedure Hello is

   --  This image's own header: the first six 32-bit fields of the
   --  manifest. The symbol is defined by the linker script
   --  (ld/slot_a/memory-ROM.ld or ld/slot_b/memory-ROM.ld).
   type Word_Array is array (0 .. 5) of Unsigned_32;
   Header : constant Word_Array with
     Import, Convention => Asm, External_Name => "__anchor_header";

   Version      : Unsigned_32 renames Header (3);
   Load_Address : Unsigned_32 renames Header (5);

   Next  : Time := Clock;
   Count : Unsigned_32 := 0;
begin
   Console.Initialize;
   Console.Put ("hello: firmware version ");
   Console.Put_Dec (Version);
   Console.Put (", running from 0x");
   Console.Put_Hex (Load_Address);
   Console.Put_Line ("");

   loop
      Next := Next + Seconds (1);
      delay until Next;
      Count := Count + 1;
      Console.Put ("hello: tick ");
      Console.Put_Dec (Count);
      Console.Put_Line ("");
   end loop;
end Hello;
