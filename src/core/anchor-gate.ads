--  The gate: the one place that decides whether an image may run.
--
--  The design rests on one idea. To start an application you must hand
--  Anchor.Boot.Jump a Ticket. Ticket is a private type, and the only
--  code that can make a valid one is Inspect, in this package's body.
--  So "no image runs unless it passed the gate" is not a convention the
--  team has to remember: the compiler and the prover enforce it.
--
--  Inspect is a pure function of bytes: it receives the whole content of
--  a slot and touches no hardware. That is what makes it provable, and
--  easy to reason about.

with Anchor.Layout;

package Anchor.Gate with
  SPARK_Mode
is

   type Verdict is
     (Accepted,
      Bad_Magic);
   --  OPEN: one value per reason to refuse an image. The seed knows a
   --  single one. The gauntlet (tests/gauntlet.robot) shows what still
   --  gets through. See docs/TRAIL.md, stops 3 to 5.

   type Ticket is private;
   --  Proof that an image passed every check.

   function Is_Valid (T : Ticket) return Boolean;

   function Slot (T : Ticket) return Layout.Slot_Id with
     Pre => Is_Valid (T);

   function Version (T : Ticket) return U32 with
     Pre => Is_Valid (T);

   procedure Inspect
     (Slot   : Layout.Slot_Id;
      Image  : Byte_Array;
      Result : out Verdict;
      T      : out Ticket)
   with
     Global => null,
     Pre    => Image'First = 0 and then Image'Length = Layout.Slot_Size,
     Post   => Is_Valid (T) = (Result = Accepted);
   --  Image is the full content of the slot: header, then payload.
   --
   --  OPEN: the postcondition above says little. Once the checks exist,
   --  it can say exactly what "Accepted" guarantees. That sentence is
   --  the security claim of the whole project.

private

   type Ticket is record
      Valid   : Boolean := False;
      Slot    : Layout.Slot_Id := Layout.A;
      Version : U32 := 0;
   end record;

   function Is_Valid (T : Ticket) return Boolean is (T.Valid);

   function Slot (T : Ticket) return Layout.Slot_Id is (T.Slot);

   function Version (T : Ticket) return U32 is (T.Version);

end Anchor.Gate;
