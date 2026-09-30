# Linker scripts

The GNAT runtime (`light_tasking_stm32f746`) links every program with its own
script, `common-ROM.ld`, which describes the sections (code, data, stack...).
That script starts with `INCLUDE memory-ROM.ld` to learn where flash is, and
`INCLUDE memory-RAM.ld` for RAM.

We keep the runtime's sections and its RAM map, and replace only the flash
region. Each program is linked with its own `memory-ROM.ld`, found before the
runtime's one because our directory comes first on the linker search path (see
the `Linker` package in `anchor.gpr` and `apps/hello.gpr`).

| File | Used by | Flash region |
|---|---|---|
| `anchor-flash.ld` | all | the numbers: bases and sizes |
| `bootloader/memory-ROM.ld` | bootloader | first 128 KiB |
| `slot_a/memory-ROM.ld` | application built for slot A | slot A, after the header |
| `slot_b/memory-ROM.ld` | application built for slot B | slot B, after the header |

To see where things really ended up, open `bin/anchor.map` after a build.
