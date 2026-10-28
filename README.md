# Inside the 6502: the programs

The small programs from Retro Computer TV's film *Inside the 6502: How 3,510 Transistors Became a Computer*. Each one shows a single thing the NMOS 6502 does, on a real machine: a Commodore 64 (its 6510), a NES (its Ricoh 2A03) or an Apple II.

| File | What it shows | Machine |
|---|---|---|
| [c64-decimal](c64/c64-decimal.asm) | Decimal mode working: with SED, $19 + $28 gives $47, and $99 + $01 gives $00 with the carry set. Then back to BASIC. | C64 |
| [nes-decimal](nes/nes-decimal.asm) | The same two additions on the NES. SED sets the flag, but the 2A03 has no decimal correction, so the sums stay binary: $41 and $9A, carry clear. | NES |
| [c64-irqmask](c64/c64-irqmask.asm) | Three counters, one tick a frame each: the main loop, an IRQ and an NMI. SEI stops only the IRQ counter. | C64 |
| [c64-jam](c64/c64-jam.asm) | The same three counters, then the opcode $02. Everything stops, the NMI too, and only a reset brings the machine back. | C64 |
| [c64-pagecross](c64/c64-pagecross.asm) | One cycle you can see: a bar drawn by a loop of exactly one raster line. In the `cross` build its indexed load crosses a page from line 80, takes a cycle longer, and the bar bends 8 pixels a line. | PAL C64 |
| [c64-rasterack](c64/c64-rasterack.asm) | A raster interrupt acknowledged with DEC $D019 (a steady band), and the same handler writing only the final value (never acknowledged: stripes, and the main program stops). | C64 |
| [c64-jmpind](c64/c64-jmpind.asm) | JMP ($02FF) takes its high byte from $0200, not $0300, and arrives at $6C34. | C64 |
| [c64-lax](c64/c64-lax.asm) | The undocumented opcode $AF loads A and X at once. | C64 |
| [c64-brk](c64/c64-brk.asm) | The status byte BRK pushes, read from the stack the way the KERNAL reads it: STACKED P = $30. | C64 |
| [c64-sysabc](c64/c64-sysabc.asm) | SYS calls machine code and BASIC carries on: ABC printed between BEFORE and AFTER. | C64 |
| [tone](apple2/tone.asm) | A speaker tone loop. Moved to $0CF8, its branch crosses a page, every pass takes one cycle more and the note drops. | Apple II |

`c64/bigfont.asm` is the double-size text that several C64 programs include.

## Building

Everything assembles with [dasm](https://github.com/dasm-assembler/dasm) (2.20 or later). With Python 3:

```sh
python build.py              # everything, into build/ (DASM=/path/to/dasm if it isn't on the PATH)
```

Or one program by hand, from its folder:

```sh
dasm c64-decimal.asm -f1 -oc64-decimal.prg
dasm c64-pagecross.asm -f1 -DCROSS=1 -oc64-pagecross-cross.prg     # CROSS=0: the straight bar
dasm c64-rasterack.asm -f1 -DACK=1 -oc64-rasterack-final.prg       # ACK=0: DEC $D019
dasm tone.asm -f3 -DORIGIN=\$0CF8 -otone-0cf8.bin                  # ORIGIN=$0300: no crossing
```

The NES test needs `build.py`, which joins the iNES header, the program and the font from `nes-font.py`.

## Running

**Commodore 64.** Most programs load at the usual BASIC start: `LOAD "C64-DECIMAL",8` and `RUN`. `c64-brk` and `c64-sysabc` load at $C000: `LOAD "C64-BRK",8,1`, then `NEW`, then `SYS 49152`. For `c64-sysabc`, type the three-line program in its header and `RUN` it. They are written for a PAL machine; `c64-pagecross` needs one, because it counts 63 cycles a line.

**NES.** `nes-decimal.nes` runs in an accurate emulator such as Mesen, or on a NES from a flash cartridge.

**Apple II.** The tone loop is eleven bytes, typed into the Monitor:

```
CALL -151
300:AD 30 C0 A2 64 CA D0 FD 4C 00 03
300G
```

Stop it with Reset, then type the same loop at $0CF8 and run it with `CF8G`. Only the JMP's address changes:

```
CF8:AD 30 C0 A2 64 CA D0 FD 4C F8 0C
```

Each pass is half a period: 508 cycles at $0300, 607 at $0CF8, so the second note is lower.

## Two to try at the keyboard

**A Commodore 64 that can't read PRINT.** At the READY prompt:

```
POKE 49300,96:POKE 783,8:SYS 49300
PRINT 2+2
```

SYS loads the processor's status register from location 783 before it calls, so 8 sets the decimal flag, and the RTS at 49300 (96) returns straight to BASIC with it still set. BASIC finds its keywords with a subtraction, which decimal mode now gets wrong: it no longer recognises PRINT, and `PRINT 2+2` gives `?SYNTAX ERROR`. Only a reset puts it right.

**BRK on an Apple II Plus.** `CALL -151`, then `300:00` and `300G`. The 6502 runs the BRK at $0300, and the Monitor stops and shows the registers.

You need your own copy of each machine's ROMs to run these in an emulator.

## Licence

MIT, see [LICENSE](LICENSE).
