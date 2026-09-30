# anchor

A SPARK bootloader for the STM32F746 that only runs firmware it can vouch for.
It runs in the [Renode](https://renode.io) emulator: no board needed.

This repository is a **seed**. It boots, it has a shape, and it is deliberately
gullible: today it runs almost anything you put in flash. Your project is to
make it refuse everything it should refuse, and to prove part of that.

```
reset
  |
  v
+------------+   inspects   +---------------------------+
| bootloader | -----------> | slot A: header + firmware |
|  (anchor)  |              +---------------------------+
+------------+              | slot B: header + firmware |
  |                         +---------------------------+
  | jumps only to an image that passed every check
  v
firmware runs
```

## Run it

You need three things installed:

- [Alire](https://alire.ada.dev), the Ada package manager
- [Renode](https://github.com/renode/renode/releases) 1.15 or newer, with `renode` on your PATH
- Python 3 (on Windows, type `python` where this page says `python3`)

Then, from the root of the repository:

```console
alr build                    # bootloader + demo application (first time: downloads the toolchain)
python3 tools/pack.py        # sign the application, make a flash image of it
python3 tools/run.py         # boot it in Renode
```

Everything you run is `alr`, Python or Renode, so the commands are the same on
Linux, macOS and Windows.

The Renode log shows the serial output of the emulated board:

```
anchor: bootloader start
anchor: crypto self-test ok
anchor: device F7460001, trust anchor D31C67E3...
anchor: slot A verdict=ACCEPTED
anchor: booting slot A, version 1
hello: firmware version 1, running from 0x08040200
hello: tick 1
hello: tick 2
```

Lines starting with `anchor:` come from the bootloader. Lines starting with
`hello:` come from the application it started. Type `quit` in the Renode
monitor to stop.

## Attack it

```console
python3 tools/attack.py                               # make hostile images from the good one
python3 tools/run.py build/attacks/unsigned.img       # boot one of them
```

That image has no valid signature, and the seed boots it anyway. That is the
problem you are here to fix.

The automatic version runs every attack and prints a scoreboard:

```console
pip install -r <your renode folder>/tests/requirements.txt     # once
renode-test tests/gauntlet.robot
```

(`renode-test` is in the Renode folder; on Windows it is `renode-test.bat`.)

On the untouched seed: **3 tests pass, 6 fail**. Each failure is an attack that
gets through.

## Prove it

```console
alr exec -- gnatprove -P prove.gpr
```

The summary is in `obj/prove/gnatprove/gnatprove.out`. The seed proves clean,
but it also claims very little. `prove.gpr` covers `src/core` and the crypto
spec: the part with no hardware in it.

## Where to go next

| Read | To learn |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | what each part is, and why it is cut that way |
| [docs/TRAIL.md](docs/TRAIL.md) | the project as seven stops, each with questions and a "done when" |
| [docs/IMAGE_FORMAT.md](docs/IMAGE_FORMAT.md) | the bytes in a slot |
| `src/boot/anchor_main.adb` | the whole boot decision, on one screen |

In the code, comments marked `OPEN:` are the places where the seed stops and
your work starts.

## Repository map

```
src/core/      decisions: layout, manifest, gate        SPARK, no hardware
src/crypto/    SHA-256 and Ed25519 (wraps SPARKNaCl)    trusted boundary
src/board/     serial console                           shared with the app
src/boot/      read a slot, jump, main                  hardware
apps/hello/    demo firmware
ld/            memory maps for the linker
tools/         pack.py (author), attack.py (adversary), run.py, keygen.py
renode/        emulated board and start script
tests/         gauntlet.robot: every attack must be refused
keys/          development signing key (test only)
anchor.gpr     builds the bootloader        apps/hello.gpr   builds the demo
prove.gpr      runs GNATprove on the core
```

## Built on

- [stm32f746g_disco](https://github.com/GNAT-Academic-Program/stm32f746g_disco), the GAP
  board crate built on GHAL (generic HAL), with its
  [light-tasking-stm32f746](https://github.com/GNAT-Academic-Program/light-tasking-stm32f746) runtime
- [SPARKNaCl](https://github.com/rod-chapman/SPARKNaCl), cryptography written and proved in SPARK
- GNAT 15 for ARM and GNATprove 15, both fetched by Alire
