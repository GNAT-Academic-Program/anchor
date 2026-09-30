package body Anchor.Manifest with
  SPARK_Mode
is

   use type U32;

   --  Read a 32-bit little-endian integer at offset At_Offset.
   function Get_U32 (Raw : Header; At_Offset : Natural) return U32 is
     (U32 (Raw (At_Offset))
      or Interfaces.Shift_Left (U32 (Raw (At_Offset + 1)), 8)
      or Interfaces.Shift_Left (U32 (Raw (At_Offset + 2)), 16)
      or Interfaces.Shift_Left (U32 (Raw (At_Offset + 3)), 24))
   with
     Pre => At_Offset <= Raw'Last - 3;

   -----------
   -- Parse --
   -----------

   procedure Parse
     (Raw    : Header;
      Result : out Status;
      M      : out Fields)
   is
   begin
      M :=
        (Format         => Get_U32 (Raw, 4),
         Device_Id      => Get_U32 (Raw, 8),
         Version        => Get_U32 (Raw, 12),
         Payload_Size   => Get_U32 (Raw, 16),
         Load_Address   => Get_U32 (Raw, 20),
         Payload_Digest => Raw (24 .. 55),
         Signature      => Raw (56 .. 119));

      if Get_U32 (Raw, 0) /= Magic then
         Result := Bad_Magic;
      else
         Result := Ok;
      end if;
   end Parse;

end Anchor.Manifest;
