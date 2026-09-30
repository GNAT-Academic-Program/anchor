with Anchor.Manifest;

package body Anchor.Gate with
  SPARK_Mode
is

   use type Manifest.Status;

   -------------
   -- Inspect --
   -------------

   procedure Inspect
     (Slot   : Layout.Slot_Id;
      Image  : Byte_Array;
      Result : out Verdict;
      T      : out Ticket)
   is
      Parsed : Manifest.Status;
      M      : Manifest.Fields;
   begin
      T := (Valid => False, Slot => Slot, Version => 0);

      --  1. Parse the header.
      Manifest.Parse
        (Raw    => Image (0 .. Layout.Header_Size - 1),
         Result => Parsed,
         M      => M);

      if Parsed /= Manifest.Ok then
         Result := Bad_Magic;
         return;
      end if;

      --  OPEN: the seed stops checking here, so anything that starts
      --  with "ANCH" boots. What is missing, in the order that makes an
      --  attacker's life hardest, is yours to decide. The tools exist:
      --
      --    Anchor.Device.Id                this device's identity
      --    Anchor.Layout                   where a payload may live
      --    Anchor.Crypto.Sha256            digest of a byte range
      --    Anchor.Crypto.Signature_Valid   Ed25519 check
      --    Anchor.Trust_Anchor.Public_Key  the key this device trusts
      --
      --  Think about order: which check must come first so that the
      --  others never look at a value nobody vouched for?

      T := (Valid => True, Slot => Slot, Version => M.Version);
      Result := Accepted;
   end Inspect;

end Anchor.Gate;
