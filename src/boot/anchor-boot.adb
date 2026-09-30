with System;
with System.Machine_Code; use System.Machine_Code;

with Anchor.Layout;

package body Anchor.Boot with
  SPARK_Mode => Off
is
   --  SPARK_Mode is Off: system registers and assembly.

   NL : constant String := ASCII.LF & ASCII.HT;

   --  Cortex-M7 system control registers (ARMv7-M Architecture Reference
   --  Manual, part B3).
   SYST_CSR : U32 with
     Import, Volatile, Address => System'To_Address (16#E000_E010#);
   ICSR     : U32 with
     Import, Volatile, Address => System'To_Address (16#E000_ED04#);
   VTOR     : U32 with
     Import, Volatile, Address => System'To_Address (16#E000_ED08#);

   type Register_Bank is array (0 .. 7) of U32 with Volatile_Components;

   NVIC_ICER : Register_Bank with
     Import, Address => System'To_Address (16#E000_E180#);
   NVIC_ICPR : Register_Bank with
     Import, Address => System'To_Address (16#E000_E280#);

   ----------
   -- Jump --
   ----------

   procedure Jump (T : Gate.Ticket) is
      Vectors : constant U32 := Layout.Payload_Base (Gate.Slot (T));
   begin
      --  The application expects the processor as it is after reset.
      --  The bootloader's runtime has turned a few things on (a timer
      --  tick, interrupts), so put them back first.

      Asm ("cpsid i", Volatile => True);    --  interrupts off

      SYST_CSR := 0;                         --  stop the SysTick timer
      for I in Register_Bank'Range loop
         NVIC_ICER (I) := 16#FFFF_FFFF#;     --  disable every IRQ
         NVIC_ICPR (I) := 16#FFFF_FFFF#;     --  and forget pending ones
      end loop;
      ICSR := 16#0A00_0000#;                 --  clear pending SysTick, PendSV

      VTOR := Vectors;                       --  the application's vectors

      --  The first two words of a Cortex-M vector table are the initial
      --  stack pointer and the address of the reset handler. Load both,
      --  go back to the main stack in privileged mode, and branch.
      Asm ("ldr r4, [%0]"     & NL &
           "ldr r5, [%0, #4]" & NL &
           "movs r6, #0"      & NL &
           "msr control, r6"  & NL &
           "isb"              & NL &
           "msr msp, r4"      & NL &
           "cpsie i"          & NL &
           "bx r5",
           Inputs   => U32'Asm_Input ("r", Vectors),
           Clobber  => "r4,r5,r6",
           Volatile => True);

      loop
         null;   --  not reached
      end loop;
   end Jump;

   ----------
   -- Halt --
   ----------

   procedure Halt (Reason : String) is
   begin
      Console.Put_Line ("anchor: " & Reason & ", halting");
      loop
         Asm ("wfi", Volatile => True);
      end loop;
   end Halt;

end Anchor.Boot;
