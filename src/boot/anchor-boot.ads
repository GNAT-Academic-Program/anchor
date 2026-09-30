--  Leaving the bootloader.
--
--  Jump is the point of no return: after it, the application owns the
--  processor. Its parameter is a Ticket, and its precondition demands a
--  valid one. Only Anchor.Gate can produce that. Read the two together.

with Anchor.Gate;
with Console;

package Anchor.Boot with
  SPARK_Mode
is

   procedure Jump (T : Gate.Ticket) with
     Global => (In_Out => Console.Port),
     Pre    => Gate.Is_Valid (T),
     No_Return;
   --  Start the application in the ticket's slot. Never returns.
   --  (The Global says: from here on the hardware, serial port included,
   --  belongs to the application.)

   procedure Halt (Reason : String) with
     Global => (In_Out => Console.Port),
     No_Return;
   --  Nothing safe to run: print "anchor: <Reason>, halting" and stop.
   --
   --  OPEN: a device that halts forever is a brick. What should a
   --  bootloader with no valid image do instead? See docs/TRAIL.md,
   --  stop 6 (recovery).

end Anchor.Boot;
