--  Text output on the board's serial console: USART1, the port wired to
--  the ST-LINK USB connector of the STM32F746G-DISCO (115200 8N1). In
--  Renode this is `sysbus.usart1`.
--
--  A thin layer over the board crate (stm32f746g_disco). We open the
--  console and nothing else: the bootloader does not need the screen,
--  the SDRAM or the touch panel, so it does not call Board.Initialize.
--
--  Shared by the bootloader and the demo application.

with Interfaces;

package Console with
  SPARK_Mode,
  Abstract_State => (Port with External => (Async_Readers, Effective_Writes)),
  Initializes    => Port
is
   --  "Port" stands for the serial port hardware. Declaring it lets SPARK
   --  code call these procedures and lets the prover know that every
   --  write matters. The body is outside SPARK: it talks to the driver.

   procedure Initialize with
     Global => (In_Out => Port);
   --  Call once before any output.

   procedure Put (Text : String) with
     Global => (In_Out => Port);

   procedure Put_Line (Text : String) with
     Global => (In_Out => Port);

   procedure Put_Hex (Value : Interfaces.Unsigned_32) with
     Global => (In_Out => Port);
   --  Eight hex digits: 16#0804_0200# prints as "08040200".

   procedure Put_Hex_Byte (Value : Interfaces.Unsigned_8) with
     Global => (In_Out => Port);
   --  Two hex digits.

   procedure Put_Dec (Value : Interfaces.Unsigned_32) with
     Global => (In_Out => Port);

end Console;
