"""Build every program here with dasm (2.20 or later, on the PATH or named by the DASM environment variable).

  python build.py   ->  run/: the C64 programs (.prg) and a disk of them all (.d64), the NES test (.nes) and the
                        Apple II tone loop (.bin); build/: listings, symbols and the NES test's parts

The disk is written by c1541, from VICE (on the PATH or named by C1541); without it the disk is left as it was.
"""

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "build"
RUN = HERE / "run"
DASM = os.environ.get("DASM", "dasm")
C1541 = os.environ.get("C1541", "c1541")

# output: (folder, source, format, defines)
PROGRAMS = {
    "c64-decimal.prg": ("c64", "c64-decimal.asm", 1, {}),
    "c64-irqmask.prg": ("c64", "c64-irqmask.asm", 1, {}),
    "c64-pagecross-straight.prg": ("c64", "c64-pagecross.asm", 1, {"CROSS": 0}),
    "c64-pagecross-cross.prg": ("c64", "c64-pagecross.asm", 1, {"CROSS": 1}),
    "c64-rasterack-dec.prg": ("c64", "c64-rasterack.asm", 1, {"ACK": 0}),
    "c64-rasterack-final.prg": ("c64", "c64-rasterack.asm", 1, {"ACK": 1}),
    "c64-jmpind.prg": ("c64", "c64-jmpind.asm", 1, {}),
    "c64-sysabc.prg": ("c64", "c64-sysabc.asm", 1, {}),
    "c64-brk.prg": ("c64", "c64-brk.asm", 1, {}),
    "c64-jam.prg": ("c64", "c64-jam.asm", 1, {}),
    "c64-lax.prg": ("c64", "c64-lax.asm", 1, {}),
    "nes-prg.bin": ("nes", "nes-decimal.asm", 3, {}),
    "tone-0300.bin": ("apple2", "tone.asm", 3, {"ORIGIN": "$0300"}),
    "tone-0cf8.bin": ("apple2", "tone.asm", 3, {"ORIGIN": "$0CF8"}),
}


# the C64 programs on the disk, by the names LOAD finds them under (16 characters at most)
DISK = {
    "c64-decimal.prg": "decimal",
    "c64-irqmask.prg": "irqmask",
    "c64-jam.prg": "jam",
    "c64-pagecross-straight.prg": "page-straight",
    "c64-pagecross-cross.prg": "page-cross",
    "c64-rasterack-dec.prg": "rasterack-dec",
    "c64-rasterack-final.prg": "rasterack-final",
    "c64-jmpind.prg": "jmpind",
    "c64-lax.prg": "lax",
    "c64-brk.prg": "brk",
    "c64-sysabc.prg": "sysabc",
}


def dasm(out: str, folder: str, src: str, fmt: int, defines: dict) -> None:
    stem = OUT / Path(out).stem
    dest = OUT if out == "nes-prg.bin" else RUN
    args = [DASM, src, f"-f{fmt}", f"-o{dest / out}", f"-l{stem}.lst", f"-s{stem}.sym"]
    args += [f"-D{k}={v}" for k, v in defines.items()]
    r = subprocess.run(args, cwd=HERE / folder, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"{out}: dasm failed\n{r.stdout}\n{r.stderr}")


def disk() -> None:
    d64 = RUN / "inside-the-6502.d64"
    args = [C1541, "-format", "inside the 6502,65", "d64", str(d64)]
    for prg, name in DISK.items():
        args += ["-write", str(RUN / prg), name]
    try:
        subprocess.run(args, check=True, capture_output=True)
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"run/{d64.name} not rebuilt: c1541 ({C1541}) did not run: {e}")


def main() -> None:
    OUT.mkdir(exist_ok=True)
    RUN.mkdir(exist_ok=True)
    for out, spec in PROGRAMS.items():
        dasm(out, *spec)
    # The NES test: an iNES header (NROM: 1 x 16 KB of program, 1 x 8 KB of tiles), the program, then our font.
    subprocess.run([sys.executable, "nes-font.py", str(OUT / "nes-font.chr")], cwd=HERE / "nes", check=True)
    prg, chr_ = (OUT / "nes-prg.bin").read_bytes(), (OUT / "nes-font.chr").read_bytes()
    assert len(prg) == 16384 and len(chr_) == 8192
    (RUN / "nes-decimal.nes").write_bytes(b"NES\x1a" + bytes([1, 1, 0, 0]) + bytes(8) + prg + chr_)
    disk()
    for f in sorted(RUN.iterdir()):
        print(f"run/{f.name}  {f.stat().st_size} bytes")


if __name__ == "__main__":
    main()
