with System.Storage_Elements;

package body Anchor.Slots with
  SPARK_Mode => Off
is
   --  SPARK_Mode is Off: this body maps an array onto a raw address.

   -------------
   -- Inspect --
   -------------

   procedure Inspect
     (Slot   : Layout.Slot_Id;
      Result : out Gate.Verdict;
      T      : out Gate.Ticket)
   is
      use System.Storage_Elements;

      Image : constant Byte_Array (0 .. Layout.Slot_Size - 1)
        with Import,
             Address => To_Address (Integer_Address (Layout.Slot_Base (Slot)));
   begin
      Gate.Inspect (Slot, Image, Result, T);
   end Inspect;

end Anchor.Slots;
