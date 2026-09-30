# The trail

Seven stops from "it boots" to "it refuses what it should, and we can show why".

Each stop has the same shape:

- **Idea**: the concept, in plain words. You may have met it in a course.
- **Where**: the files to open.
- **Try**: something small to do with your hands first.
- **Questions**: what to be able to answer. Look things up, argue, ask.
- **Done when**: how you know you can move on.

The stops say what to understand and what must be true at the end. They do not
say how to write it. Stops 1 and 2 are for both of you, in the first week. After
that the trail is not a strict order: 3, 4, 5 build the gate, 7 runs next to
them from the start, 6 comes once the gate holds.

One way to split the work between two people: one builds the wall (stops 3 to
6), one attacks it (stop 7, plus the threat model). Review each other's work,
so that both of you touch SPARK and both of you write attacks.

---

## Stop 1. What happens at reset

**Idea.** A microcontroller has no operating system to load your program. At
reset the processor reads two numbers from a fixed place in flash (the start
of the *vector table*): where the stack is, and where the first instruction
is. Then it runs. A bootloader is simply the program that sits at that place,
so it always runs first, and later hands the processor to another program by
doing by hand what reset does.

**Where.** `src/boot/anchor_main.adb`, `src/boot/anchor-boot.adb`,
`renode/anchor.resc`.

**Try.** Run the seed (`python3 tools/run.py`). In the Renode monitor, before and after the jump, type
`sysbus.cpu PC` and `sysbus.cpu VectorTableOffset`. Type `pause`, `start`.
Read the two first words of each program: `sysbus ReadDoubleWord 0x08000000`,
`sysbus ReadDoubleWord 0x08000004`, then the same at `0x08040200`.

**Questions.**
- In the log, which lines come from which program? How do you know?
- `Jump` turns off the timer and the interrupts before branching. What could
  go wrong in the application if it did not?
- The application prints a tick every second. Why does that tick prove the
  jump was done properly?

**Done when.** Each of you can draw, from memory, the path from reset to
`hello: tick 1` and name the file responsible for each step.

---

## Stop 2. The memory map

**Idea.** The linker decides the address of everything. A *linker script*
tells it which memory regions exist. We have two programs in one flash, so
each gets its own region, and a program only works at the address it was
linked for.

**Where.** `ld/README.md`, `ld/anchor-flash.ld`, `src/core/anchor-layout.ads`,
`bin/anchor.map` (after a build), [IMAGE_FORMAT.md](IMAGE_FORMAT.md).

**Try.** Build the application for slot B (`alr build -- -XANCHOR_SLOT=b`),
pack it (`python3 tools/pack.py --slot b --version 2`), and boot with both
slots filled (`python3 tools/run.py --slot-b build/slot_b.img`). Which image
boots, and why that one? Then put garbage in A and, in B, the image that was
built for A (`python3 tools/run.py build/attacks/bad_magic.img --slot-b
build/slot_a.img`). What happens, and which check would have caught it?

**Questions.**
- How big is the bootloader today, and what takes the most room? (The map file
  knows.) What happens at link time if it outgrows its region?
- Why do region boundaries follow the chip's erase sectors?
- The same numbers are written in three files. What breaks if they disagree?
  Could one file be generated from another?

**Done when.** You can take any address printed in the log and say which
region it is in and which program owns it.

---

## Stop 3. Parsing bytes you do not trust

**Idea.** The header is input from outside. A parser that trusts it is the
classic way in: a size field that lies, an address that points elsewhere, a
value that overflows when you add to it. In most languages these are bugs you
find later. In SPARK you can prove, before running anything, that no sequence
of 512 bytes can make the parser misbehave.

**Where.** `src/core/anchor-manifest.ads` and `.adb`,
[IMAGE_FORMAT.md](IMAGE_FORMAT.md), the attack `size_overflow` in
`tools/attack.py`.

**Try.** Run `alr exec -- gnatprove -P prove.gpr` and read the report for
`anchor-manifest.adb`: each line is a possible run-time error and why it
cannot happen. Now weaken the precondition of `Get_U32` and run it again.

**Questions.**
- The seed checks one field. For each other field: which values are nonsense
  no matter who signed the image? Those belong to the parser.
- `Payload_Size` is a `U32`. Where will it be used as an array bound? What must
  be true of it before that, and how can a type say so?
- What is the difference between "this manifest is malformed" and "this
  manifest is well-formed but I do not accept it"? Which package owns which?

**Done when.** `Parse` refuses every header that is nonsense on its face, each
reason has its own `Status` value, and GNATprove reports no unproved check in
the package.

---

## Stop 4. Same bytes, right author

**Idea.** Two different questions. A **hash** (SHA-256) answers "are these
exactly the same bytes?" A **signature** (Ed25519) answers "did the holder of
the private key approve this?" A checksum alone protects nothing: an attacker
who changes the program also changes the checksum. The signature is checked
with a public key built into the bootloader, the **trust anchor**. Everything
the device believes comes from that key.

**Where.** `src/crypto/anchor-crypto.ads`, `src/crypto/anchor-trust_anchor.ads`,
`tools/anchor_image.py`, `keys/README.md`.

**Try.** Follow the second part of [IMAGE_FORMAT.md](IMAGE_FORMAT.md): compute
the digest of the payload yourself and find it in the header. Then run the
attacks `flipped_payload_bit`, `unsigned` and `wrong_key` by hand and look at
what the seed does with each.

**Questions.**
- The signature covers 56 bytes, not the whole image. Why is that enough?
- Which attack does the digest stop? Which does the signature stop? Is there
  one that needs both?
- Where must the trust anchor be stored so that an update can never replace
  it? What would it take to change it on purpose?
- We use a library for the cryptography and do not prove it. What exactly are
  we trusting, and where is that line drawn in the code?

**Done when.** The gate checks both, and you can explain to someone outside
the project why neither one alone would do.

---

## Stop 5. The gate and its claim

**Idea.** All checks live in one procedure, `Anchor.Gate.Inspect`, and the
only way to start an image is with the `Ticket` it returns. That gives the
project one sentence it can defend: *"an image runs only if ..."*. The rest
of that sentence is the postcondition of `Inspect`. Order matters too: until
the signature is verified, every field of the manifest is a rumour.

**Where.** `src/core/anchor-gate.ads` and `.adb`, `src/boot/anchor-boot.ads`,
[ARCHITECTURE.md](../ARCHITECTURE.md) section "The central idea".

**Try.** In `anchor_main.adb`, try to call `Jump` with a ticket you build
yourself. Read what the compiler says. Then call `Jump` without testing
`Is_Valid` first: what should catch that, and does it today? (Read the header
of `prove.gpr`.)

**Questions.**
- In which order should the checks run, and what is the reason for each
  position?
- Device identity, size, load address: `Anchor.Device` and `Anchor.Layout`
  have what you need. What does "this image is for me and fits here" mean,
  exactly?
- What would you like the postcondition to say? What can it say with the
  tools you have? The gap between the two is worth writing down.
- The image is checked, then started a moment later. Could it change in
  between? On this device? On another design?

**Done when.** Every test in `tests/gauntlet.robot` passes, each refusal
prints its own `Verdict`, and GNATprove is clean on `prove.gpr`.

---

## Stop 6. Which image, and what if it is bad

**Idea.** Signed firmware can still be broken firmware. Real devices keep two
slots: install the new version next to the old one, try it, and go back if it
does not come up. To do that the bootloader must **remember** things between
resets: which slot is current, the highest version seen, how many times it
tried. That memory lives in flash, and a power cut can land in the middle of
writing it.

**Where.** The `OPEN:` notes in `src/boot/anchor_main.adb` and
`src/boot/anchor-boot.ads`. The reserved metadata regions in
`src/core/anchor-layout.ads`. The note on flash in
[ARCHITECTURE.md](../ARCHITECTURE.md), "What Renode does and does not model".

This stop is the least built in the seed, on purpose: the design is yours.
Bring a one-page proposal to your mentor before writing code.

**Questions.**
- Both slots hold a valid image. Which one boots? Who decides: the manifest
  version, a stored state, both?
- An old version with a known flaw is still correctly signed. What stops
  someone from putting it back (a *downgrade*)? What must be stored for that?
- The new image is valid but crashes at start. How does the bootloader find
  out? How does a healthy application say "I am fine"?
- The power fails while the state is being written. What does the bootloader
  read at the next reset? How do two copies help? What if both are bad?
- Nothing is bootable. Halting forever makes a brick. What is the smallest
  useful *recovery* behaviour?
- Renode's flash is plain memory. Do you write to it directly behind a small
  interface, or model the real flash controller? What does each choice cost?

**Done when.** A demo shows: update from version 1 to 2; a downgrade refused;
a broken version 2 abandoned for version 1 without anyone touching the board;
a reset in the middle of a state write survived.

---

## Stop 7. Be the adversary

**Idea.** You cannot claim a lock works if you never tried to pick it. A
**threat model** is the organised version of that: who attacks, what they
control, what they want, and for each combination, what stops them or why you
accept the risk. Here the adversary controls everything outside the chip: the
bytes in the slots, and the moment of each reset.

**Where.** `tools/attack.py`, `tests/gauntlet.robot`.

**Try.** Run `python3 tools/attack.py --list`. Read two attacks, then write a
new one and its test. Make it one the current bootloader does not stop.

**Questions.**
- For each attack in the list: what does the attacker need to have or know?
  Which check stops it? Is there a second check that would also stop it?
- What can an attacker do that is *not* a bad image? Think about timing,
  about the second slot, about images that are valid but old.
- Seven hand-written attacks are a sample. How would you generate thousands
  (random mutations of a good image) and what would you check on each run?
- Which attacks does this design not stop at all? A stolen signing key, for
  example. Saying so clearly is part of the result.

**Done when.** There is a threat table (adversary, goal, attack, mitigation or
accepted risk), every line that has a mitigation has a test, and the list of
what is *not* covered is written down.

---

## If there is time left

Pick by interest, not in order.

- **Recovery loader**: with nothing bootable, accept a new image over the
  serial port. A second parser fed by an attacker, with a bounded buffer.
  (From the laptop, reach the UART with Renode's `CreateServerSocketTerminal`.)
- **Real hardware**: the same binaries on a physical STM32F746 Discovery.
- **A smaller bootloader**: most of its size is hardware library code it never
  calls. How small can the trusted part get?
- **Key rotation**: replace the trust anchor on purpose, safely.

## Reading

- [Learn SPARK](https://learn.adacore.com/courses/intro-to-spark/index.html),
  chapters 1 to 4 are enough to start.
- [Learn Ada](https://learn.adacore.com/courses/intro-to-ada/index.html),
  especially strong typing, records, arrays, packages and privacy.
- [NIST SP 800-193](https://csrc.nist.gov/pubs/sp/800/193/final), *Platform
  Firmware Resiliency Guidelines*: protect, detect, recover. Short, and it
  gives you the vocabulary.
- [RFC 9019](https://www.rfc-editor.org/info/rfc9019/) and
  [RFC 9124](https://www.rfc-editor.org/info/rfc9124/): how the IETF describes
  firmware updates and what belongs in a manifest.
- [MCUboot design](https://docs.mcuboot.com/design.html): how a widely used
  open-source bootloader answers the questions of stop 6.
- [Renode documentation](https://renode.readthedocs.io), and
  [testing with Robot Framework](https://renode.readthedocs.io/en/latest/introduction/testing.html).
