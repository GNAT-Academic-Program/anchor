--  Who this device is.
--
--  A manifest names the device it was built for. A bootloader that does
--  not compare that field with its own identity will happily run firmware
--  meant for another product.

package Anchor.Device with
  Pure,
  SPARK_Mode
is

   Id : constant U32 := 16#F746_0001#;

end Anchor.Device;
