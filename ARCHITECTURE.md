# Architecture

## The problem in one paragraph

Firmware is the most privileged software on a device. If an attacker can get a
modified image to run, they own the device for good. A bootloader is the guard
at the door: it runs first after every reset, looks at the firmware in flash,
and decides whether to start it. `anchor` is that guard. The name comes from
**trust anchor**: the one public key built into the bootloader, from which
every other decision to trust something is derived.

## The pieces

```
                 laptop                          emulated STM32F746
        +----------------------+        +-----------------------------------+
        | tools/pack.py        |        | flash                             |
        |   author: signs      | -----> |   0x08000000  bootloader (anchor) |
        | tools/attack.py      | images |   0x08040000  slot A              |
        |   adversary: tampers | -----> |   0x08080000  slot B              |
        +----------------------+        +-----------------------------------+
```

The laptop plays two roles: the honest firmware **author**, who holds the
private key, and the **adversary**, who does not but controls everything else.

## Flash map

| Address | Size | Content |
|---|---|---|
| `0x08000000` | 128 KiB | bootloader |
| `0x08020000` | 128 KiB | metadata copy 0 (reserved, unused in the seed) |
| `0x08040000` | 256 KiB | slot A |
| `0x08080000` | 256 KiB | slot B |
| `0x080C0000` | 256 KiB | metadata copy 1 (reserved, unused in the seed) |

Three things follow from this map:

1. **Regions match the chip's erase sectors.** Flash is erased a whole sector
   at a time. With this cut, erasing one region never touches another.
2. **An image runs where it is.** Nothing is copied at boot. An application is
   linked for slot A or for slot B, and only works there.
3. **Two slots** means a new version can be installed next to the old one, and
   the old one is still there if the new one is bad.

The numbers live in three places that must agree: `ld/anchor-flash.ld` (linker),
`src/core/anchor-layout.ads` (Ada), `tools/anchor_image.py` (Python).

## What is in a slot

```
slot base                                                       slot end
|<---- header, 512 bytes ---->|<------------- payload ------------->|
| manifest | signature | pad  | vector table | program ...          |
```

- **payload**: the program. Its first two words are what a Cortex-M needs to
  start: the initial stack pointer and the address of the first instruction.
- **manifest**: what the image says about itself: which device it is for, its
  version, its size, and the SHA-256 digest of the payload.
- **signature**: Ed25519 signature of the manifest, made with the private key.

Because the manifest contains the digest of the payload, signing the manifest
is enough to cover the whole image. Details: [docs/IMAGE_FORMAT.md](docs/IMAGE_FORMAT.md).

## Code layout

The source tree is cut by one rule: **decisions are separated from hardware.**

```
        src/boot  (hardware)                 src/core  (decisions, SPARK)
   +---------------------------+        +--------------------------------+
   | anchor_main   the sequence|        | Anchor.Layout    where things  |
   | Anchor.Slots  read a slot | -----> |                  are           |
   | Anchor.Boot   jump, halt  | bytes  | Anchor.Manifest  bytes to      |
   +---------------------------+        |                  fields        |
                 ^                      | Anchor.Gate      accept or     |
                 |  Ticket              |                  refuse        |
                 +--------------------- +--------------------------------+
                                                       |
                                                       v
                                        +--------------------------------+
                                        | src/crypto                     |
                                        | Anchor.Crypto       SHA-256,   |
                                        |                     Ed25519    |
                                        | Anchor.Trust_Anchor public key |
                                        +--------------------------------+
```

| Package | File | Job | SPARK |
|---|---|---|---|
| `Anchor` | `src/core/anchor.ads` | basic types: `Byte`, `U32`, `Byte_Array` | yes |
| `Anchor.Layout` | `src/core/anchor-layout.ads` | flash map, as Ada constants | yes |
| `Anchor.Device` | `src/core/anchor-device.ads` | this device's identity | yes |
| `Anchor.Manifest` | `src/core/anchor-manifest.ad[sb]` | turn 512 raw bytes into a typed record | yes, proved |
| `Anchor.Gate` | `src/core/anchor-gate.ad[sb]` | decide: accept or refuse, and say why | yes, proved |
| `Anchor.Crypto` | `src/crypto/anchor-crypto.ad[sb]` | SHA-256, Ed25519 verify, self-test | spec only |
| `Anchor.Trust_Anchor` | `src/crypto/anchor-trust_anchor.ads` | the public key (generated) | yes |
| `Anchor.Slots` | `src/boot/anchor-slots.ad[sb]` | point a byte array at a flash slot | spec only |
| `Anchor.Boot` | `src/boot/anchor-boot.ad[sb]` | `Jump` to an image, or `Halt` | spec only |
| `Console` | `src/board/console.ad[sb]` | print on the serial port, through the board crate | spec only |

"Spec only" means the contract is in SPARK and callers are checked against it,
but the body is outside SPARK because it touches raw addresses or registers.
Those bodies are small on purpose. They are the **trusted** part: nothing
proves them, so they must be simple enough to review by reading.

GNATprove runs through `prove.gpr`, which covers `src/core` and the spec of
`src/crypto`. The main program is written in SPARK too, so the call to `Jump`
can be checked the day GNATprove runs on the whole bootloader (the header of
`prove.gpr` says when and how).

The hardware side stands on the GAP board crate `stm32f746g_disco` (GHAL). The
bootloader uses one thing from it, the console (`Board.Console`, `Debug`). It
does not call `Board.Initialize`: a bootloader has no use for the screen, the
SDRAM or the touch panel, and every driver it starts is more code to trust.

Why this cut matters: `Anchor.Gate.Inspect` takes an array of bytes and returns
a verdict. It does not know what flash is. So the prover can reason about it
completely, and the question "can a bad image get through?" is answered in one
package instead of being spread across drivers.

## The central idea: the Ticket

```ada
--  Anchor.Gate
type Ticket is private;
procedure Inspect (Slot; Image : Byte_Array; Result : out Verdict; T : out Ticket)
  with Post => Is_Valid (T) = (Result = Accepted);

--  Anchor.Boot
procedure Jump (T : Gate.Ticket)
  with Pre => Gate.Is_Valid (T);
```

To start an application you must give `Jump` a valid `Ticket`. `Ticket` is
private: outside `Anchor.Gate`, no code can build one or edit one. The only way
to get a valid ticket is for `Inspect` to return `Accepted`.

So the rule "nothing runs unless it passed the gate" is not something the team
must remember. The compiler refuses code that forges a ticket, and the prover
refuses a call to `Jump` that might hold an invalid one.

What the seed leaves open is what `Accepted` **means**. Today it means "the
header starts with ANCH". The project is to make it mean much more, and to
write that meaning in the postcondition of `Inspect`.

## Boot sequence

What happens from reset, and where to read it:

1. The processor loads its stack pointer and first instruction address from
   the vector table at `0x08000000`. That is the bootloader.
2. The GNAT runtime starts (clocks, memory), then calls `Anchor_Main`.
3. `Console.Initialize`, then the crypto self-test, then one line saying who
   this device is and which key it trusts.
4. For each slot: `Anchor.Slots.Inspect`, print the verdict.
5. First valid ticket: `Anchor.Boot.Jump`. The bootloader switches off what its
   runtime switched on (timer, interrupts), points the processor at the
   application's vector table, and branches. It never comes back.
6. No valid ticket: `Anchor.Boot.Halt`, with the reason.

Step 5 contains the only machine instructions in the project (eight of them,
in `anchor-boot.adb`). They are done. You call `Jump`; you do not edit it.

## The serial log is an interface

Every bootloader line starts with `anchor:`. The tests in
`tests/gauntlet.robot` wait for these exact lines, in particular:

```
anchor: slot A verdict=ACCEPTED
```

The word after `verdict=` is the `Verdict` value, printed with `'Image`. Add a
value to the type and it shows up in the log for free. If you reword a line,
update the tests in the same commit.

## What Renode does and does not model

- The processor, RAM, the UART, timers, GPIO: yes. The code is the same binary
  that would run on a real Discovery board.
- Flash is modelled as plain memory. There is no erase/program sequence, and
  an empty byte reads `0x00` where real flash reads `0xFF`. This matters the
  day the bootloader has to **write** something (see the trail, stop 6).
- To talk to the UART from a program on the laptop, use
  `emulation CreateServerSocketTerminal` (a TCP port). It works on every OS.
  The PTY terminal does not exist on Windows.

## House rules

Short, and meant to be argued with in review.

1. **No hardware in `src/core`.** If a core package needs `System.Address` or a
   register, the cut is wrong.
2. **Say it with a type.** A `Slot_Id` is not an integer. A size that must fit
   in a slot is a subtype with that range. Let the compiler carry the rule.
3. **Every refusal has a name.** One `Verdict` value per reason. "Rejected" with
   no reason is not debuggable and not testable.
4. **An attack comes with its test.** New function in `tools/attack.py`, new
   line in `tests/gauntlet.robot`, same commit.
5. **You can explain every line you commit.** Whatever wrote the first draft.
