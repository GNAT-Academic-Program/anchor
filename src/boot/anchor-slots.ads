--  Hardware side of the gate: look at what is really in a flash slot.
--
--  Anchor.Gate.Inspect works on a plain array of bytes. This package is
--  the adapter that points such an array at the slot in flash (no copy)
--  and calls the gate.

with Anchor.Gate;
with Anchor.Layout;

package Anchor.Slots with
  SPARK_Mode
is

   use type Gate.Verdict;

   procedure Inspect
     (Slot   : Layout.Slot_Id;
      Result : out Gate.Verdict;
      T      : out Gate.Ticket)
   with
     Post => Gate.Is_Valid (T) = (Result = Gate.Accepted);

end Anchor.Slots;
