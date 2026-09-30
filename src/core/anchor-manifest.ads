--  The manifest: what an image claims about itself.
--
--  Every slot starts with a 512 byte header. Its layout (format 1, all
--  integers little-endian) is documented in docs/IMAGE_FORMAT.md:
--
--     offset  size  field
--          0     4  magic          "ANCH"
--          4     4  format         1
--          8     4  device id      the device this image is for
--         12     4  version        firmware version, must only go up
--         16     4  payload size   in bytes
--         20     4  load address   where the payload must sit in flash
--         24    32  payload digest SHA-256 of the payload
--         56    64  signature      Ed25519 over bytes 0 .. 55
--        120   392  padding
--
--  This package turns those raw bytes into a typed record. Nothing else.
--  It does not decide whether the image is trustworthy: see Anchor.Gate.
--
--  The header comes from outside, so treat every byte as hostile.

with Anchor.Crypto;
with Anchor.Layout;

package Anchor.Manifest with
  SPARK_Mode
is

   subtype Header is Byte_Array (0 .. Layout.Header_Size - 1);

   Magic : constant U32 := 16#4843_4E41#;   --  bytes 'A' 'N' 'C' 'H'

   --  The signature covers the header bytes 0 .. Signed_Length - 1.
   Signed_Length : constant := 56;

   type Fields is record
      Format         : U32;
      Device_Id      : U32;
      Version        : U32;
      Payload_Size   : U32;
      Load_Address   : U32;
      Payload_Digest : Crypto.Digest;
      Signature      : Crypto.Signature;
   end record;

   type Status is
     (Ok,
      Bad_Magic);
   --  OPEN: the seed only checks the magic. Which other fields can be
   --  wrong in a way that is visible from the header alone? Each one
   --  deserves its own Status value. See docs/TRAIL.md, stop 3.

   procedure Parse
     (Raw    : Header;
      Result : out Status;
      M      : out Fields)
   with
     Global => null;
   --  Decode Raw into M. M is meaningful only when Result = Ok.

end Anchor.Manifest;
