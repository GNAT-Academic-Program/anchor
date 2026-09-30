with Board;
with Console_GPIO;
with Debug;
with Usart_Types;

package body Console with
  SPARK_Mode => Off
is

   use type Interfaces.Unsigned_32;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Console_GPIO.Configure;
      Board.Console.Open
        ((Baud      => Usart_Types.B115200,
          Data_Bits => Usart_Types.Data_8,
          Parity    => Usart_Types.None,
          Stop_Bits => Usart_Types.Stop_1,
          Flow      => Usart_Types.None));
   end Initialize;

   ---------
   -- Put --
   ---------

   procedure Put (Text : String) renames Debug.Put;

   --------------
   -- Put_Line --
   --------------

   procedure Put_Line (Text : String) renames Debug.Put_Line;

   -------------
   -- Put_Hex --
   -------------

   procedure Put_Hex (Value : Interfaces.Unsigned_32) is
      Digit : constant String := "0123456789ABCDEF";
      Text  : String (1 .. 8);
      V     : Interfaces.Unsigned_32 := Value;
   begin
      for I in reverse Text'Range loop
         Text (I) := Digit (Natural (V and 16#F#) + 1);
         V := Interfaces.Shift_Right (V, 4);
      end loop;
      Put (Text);
   end Put_Hex;

   ------------------
   -- Put_Hex_Byte --
   ------------------

   procedure Put_Hex_Byte (Value : Interfaces.Unsigned_8) is
      use type Interfaces.Unsigned_8;
      Digit : constant String := "0123456789ABCDEF";
   begin
      Put ((1 => Digit (Natural (Interfaces.Shift_Right (Value, 4)) + 1),
            2 => Digit (Natural (Value and 16#F#) + 1)));
   end Put_Hex_Byte;

   -------------
   -- Put_Dec --
   -------------

   procedure Put_Dec (Value : Interfaces.Unsigned_32) is
      Text  : String (1 .. 10);
      First : Natural := Text'Last + 1;
      V     : Interfaces.Unsigned_32 := Value;
   begin
      loop
         First := First - 1;
         Text (First) :=
           Character'Val (Character'Pos ('0') + Natural (V mod 10));
         V := V / 10;
         exit when V = 0;
      end loop;
      Put (Text (First .. Text'Last));
   end Put_Dec;

end Console;
