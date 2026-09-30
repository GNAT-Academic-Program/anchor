--  The two cryptographic operations the bootloader needs.
--
--  We do NOT write cryptography ourselves. This package is a thin
--  wrapper over SPARKNaCl, a library written and proved in SPARK. It is
--  a trusted boundary: we rely on it, we do not re-prove it.
--
--     Sha256           answers "are these exactly the bytes that were
--                      measured when the image was built?"
--     Signature_Valid  answers "did the holder of the private key
--                      approve this message?"
--
--  Neither answers the other's question. The gate needs both.

package Anchor.Crypto with
  SPARK_Mode
is

   subtype Digest is Byte_Array (0 .. 31);
   subtype Signature is Byte_Array (0 .. 63);
   subtype Public_Key is Byte_Array (0 .. 31);

   Max_Message_Length : constant := 1024;

   function Sha256 (Data : Byte_Array) return Digest with
     Global => null;
   --  SHA-256 of Data. Data is read in place: hashing a whole payload
   --  straight from flash costs no RAM copy.

   function Signature_Valid
     (Message : Byte_Array;
      Sig     : Signature;
      Key     : Public_Key) return Boolean
   with
     Global => null,
     Pre    => Message'Length in 1 .. Max_Message_Length;
   --  True when Sig is a valid Ed25519 signature of Message under Key.

   function Self_Test return Boolean with
     Global => null;
   --  Known-answer test of both operations, run at every boot. If the
   --  crypto is broken (bad build, wrong compiler switch...), we want
   --  to know before trusting any of its answers.

end Anchor.Crypto;
