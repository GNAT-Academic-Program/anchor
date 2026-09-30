--  The bootloader's main program: the first code that runs after reset.
--
--  Read this file first. It is the whole boot decision on one screen.
--  Everything it prints starts with "anchor:" and the tests rely on
--  these lines, so treat them as an interface.

with Anchor.Boot;
with Anchor.Crypto;
with Anchor.Device;
with Anchor.Gate;
with Anchor.Layout;
with Anchor.Slots;
with Anchor.Trust_Anchor;
with Console;

procedure Anchor_Main with
  SPARK_Mode
is
   Result : Anchor.Gate.Verdict;
   Ticket : Anchor.Gate.Ticket;
begin
   Console.Initialize;
   Console.Put_Line ("");
   Console.Put_Line ("anchor: bootloader start");

   if not Anchor.Crypto.Self_Test then
      Anchor.Boot.Halt ("crypto self-test FAILED");
   end if;
   Console.Put_Line ("anchor: crypto self-test ok");

   --  Say who we are and whom we trust (first 4 bytes of the public key).
   Console.Put ("anchor: device ");
   Console.Put_Hex (Anchor.Device.Id);
   Console.Put (", trust anchor ");
   for I in 0 .. 3 loop
      Console.Put_Hex_Byte (Anchor.Trust_Anchor.Public_Key (I));
   end loop;
   Console.Put_Line ("...");

   --  OPEN: the seed tries A, then B, and boots the first image the gate
   --  accepts. It remembers nothing between resets. Which slot SHOULD
   --  boot when both are valid? What if the newest one crashes? That is
   --  docs/TRAIL.md, stop 6.
   for Slot in Anchor.Layout.Slot_Id loop
      Anchor.Slots.Inspect (Slot, Result, Ticket);

      Console.Put_Line
        ("anchor: slot " & Slot'Image & " verdict=" & Result'Image);

      if Anchor.Gate.Is_Valid (Ticket) then
         Console.Put ("anchor: booting slot " & Slot'Image & ", version ");
         Console.Put_Dec (Anchor.Gate.Version (Ticket));
         Console.Put_Line ("");
         Anchor.Boot.Jump (Ticket);
      end if;
   end loop;

   Anchor.Boot.Halt ("no bootable image");
end Anchor_Main;
