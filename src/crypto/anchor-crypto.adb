with SPARKNaCl;
with SPARKNaCl.Hashing.SHA256;
with SPARKNaCl.Sign;

package body Anchor.Crypto with
  SPARK_Mode => Off
is
   --  SPARK_Mode is Off here because of the address overlay in Sha256.
   --  This body is small and reviewed by hand; the code that matters for
   --  proof is on the other side of the spec.

   use type SPARKNaCl.I32;

   ------------
   -- Sha256 --
   ------------

   function Sha256 (Data : Byte_Array) return Digest is
      Result : Digest;
   begin
      if Data'Length = 0 then
         declare
            Empty : constant SPARKNaCl.Byte_Seq (1 .. 0) := (others => 0);
            D     : constant SPARKNaCl.Bytes_32 :=
              SPARKNaCl.Hashing.SHA256.Hash (Empty);
         begin
            for I in Result'Range loop
               Result (I) := D (SPARKNaCl.N32 (I));
            end loop;
         end;
      else
         declare
            --  Same bytes, seen with SPARKNaCl's array type. Both types
            --  are arrays of 8-bit unsigned values, so no copy is needed.
            View : constant SPARKNaCl.Byte_Seq
                     (0 .. SPARKNaCl.N32 (Data'Length - 1))
              with Import, Address => Data'Address;
            D    : SPARKNaCl.Bytes_32;
         begin
            SPARKNaCl.Hashing.SHA256.Hash (D, View);
            for I in Result'Range loop
               Result (I) := D (SPARKNaCl.N32 (I));
            end loop;
         end;
      end if;
      return Result;
   end Sha256;

   ---------------------
   -- Signature_Valid --
   ---------------------

   function Signature_Valid
     (Message : Byte_Array;
      Sig     : Signature;
      Key     : Public_Key) return Boolean
   is
      --  SPARKNaCl checks a "signed message": signature, then message.
      Total  : constant SPARKNaCl.N32 :=
        SPARKNaCl.N32 (Sig'Length + Message'Length);
      Signed : SPARKNaCl.Byte_Seq (0 .. Total - 1);
      Opened : SPARKNaCl.Byte_Seq (0 .. Total - 1);
      Raw_PK : SPARKNaCl.Bytes_32;
      PK     : SPARKNaCl.Sign.Signing_PK;
      Ok     : Boolean;
      Length : SPARKNaCl.I32;
   begin
      for I in Sig'Range loop
         Signed (SPARKNaCl.N32 (I)) := Sig (I);
      end loop;
      for I in Message'Range loop
         Signed (SPARKNaCl.N32 (Sig'Length + (I - Message'First))) :=
           Message (I);
      end loop;
      for I in Key'Range loop
         Raw_PK (SPARKNaCl.N32 (I)) := Key (I);
      end loop;

      SPARKNaCl.Sign.PK_From_Bytes (Raw_PK, PK);
      SPARKNaCl.Sign.Open
        (M      => Opened,
         Status => Ok,
         MLen   => Length,
         SM     => Signed,
         PK     => PK);

      return Ok and then Length = SPARKNaCl.I32 (Message'Length);
   end Signature_Valid;

   ---------------
   -- Self_Test --
   ---------------

   function Self_Test return Boolean is

      --  SHA-256 ("abc"), from FIPS 180-4.
      Abc        : constant Byte_Array := (16#61#, 16#62#, 16#63#);
      Abc_Digest : constant Digest :=
        (16#BA#, 16#78#, 16#16#, 16#BF#, 16#8F#, 16#01#, 16#CF#, 16#EA#,
         16#41#, 16#41#, 16#40#, 16#DE#, 16#5D#, 16#AE#, 16#22#, 16#23#,
         16#B0#, 16#03#, 16#61#, 16#A3#, 16#96#, 16#17#, 16#7A#, 16#9C#,
         16#B4#, 16#10#, 16#FF#, 16#61#, 16#F2#, 16#00#, 16#15#, 16#AD#);

      --  Ed25519 test vector 2 from RFC 8032, section 7.1.
      Key : constant Public_Key :=
        (16#3D#, 16#40#, 16#17#, 16#C3#, 16#E8#, 16#43#, 16#89#, 16#5A#,
         16#92#, 16#B7#, 16#0A#, 16#A7#, 16#4D#, 16#1B#, 16#7E#, 16#BC#,
         16#9C#, 16#98#, 16#2C#, 16#CF#, 16#2E#, 16#C4#, 16#96#, 16#8C#,
         16#C0#, 16#CD#, 16#55#, 16#F1#, 16#2A#, 16#F4#, 16#66#, 16#0C#);
      Msg : constant Byte_Array := (1 => 16#72#);
      Sig : constant Signature :=
        (16#92#, 16#A0#, 16#09#, 16#A9#, 16#F0#, 16#D4#, 16#CA#, 16#B8#,
         16#72#, 16#0E#, 16#82#, 16#0B#, 16#5F#, 16#64#, 16#25#, 16#40#,
         16#A2#, 16#B2#, 16#7B#, 16#54#, 16#16#, 16#50#, 16#3F#, 16#8F#,
         16#B3#, 16#76#, 16#22#, 16#23#, 16#EB#, 16#DB#, 16#69#, 16#DA#,
         16#08#, 16#5A#, 16#C1#, 16#E4#, 16#3E#, 16#15#, 16#99#, 16#6E#,
         16#45#, 16#8F#, 16#36#, 16#13#, 16#D0#, 16#F1#, 16#1D#, 16#8C#,
         16#38#, 16#7B#, 16#2E#, 16#AE#, 16#B4#, 16#30#, 16#2A#, 16#EE#,
         16#B0#, 16#0D#, 16#29#, 16#16#, 16#12#, 16#BB#, 16#0C#, 16#00#);

      --  The same message with one bit changed must be refused.
      Bad_Msg : constant Byte_Array := (1 => 16#73#);
   begin
      return Sha256 (Abc) = Abc_Digest
        and then Signature_Valid (Msg, Sig, Key)
        and then not Signature_Valid (Bad_Msg, Sig, Key);
   end Self_Test;

end Anchor.Crypto;
