"""Our own 8 x 8 font for the NES decimal test, doubled to 16 x 16 (four tiles a glyph), as an 8 KB CHR bank.

  python nes-font.py <out.chr>

Tile 0 is blank; glyph k (in GLYPHS order) is tiles 1+4k (top left), 2+4k (top right), 3+4k (bottom left) and
4+4k (bottom right). Pixels use colour 1 of the background palette. The drawings below are ours.
"""

import sys

GLYPHS = "0123456789ABCDEFRY+="

DRAW = {
    "0": [".XXXXX..", "XX...XX.", "XX..XXX.", "XX.X.XX.", "XXX..XX.", "XX...XX.", ".XXXXX..", "........"],
    "1": ["...XX...", "..XXX...", "...XX...", "...XX...", "...XX...", "...XX...", ".XXXXXX.", "........"],
    "2": [".XXXXX..", "XX...XX.", ".....XX.", "...XXX..", ".XXX....", "XX......", "XXXXXXX.", "........"],
    "3": [".XXXXX..", "XX...XX.", ".....XX.", "..XXXX..", ".....XX.", "XX...XX.", ".XXXXX..", "........"],
    "4": ["....XXX.", "...XXXX.", "..XX.XX.", ".XX..XX.", "XXXXXXX.", ".....XX.", ".....XX.", "........"],
    "5": ["XXXXXXX.", "XX......", "XXXXXX..", ".....XX.", ".....XX.", "XX...XX.", ".XXXXX..", "........"],
    "6": ["..XXXX..", ".XX.....", "XX......", "XXXXXX..", "XX...XX.", "XX...XX.", ".XXXXX..", "........"],
    "7": ["XXXXXXX.", "XX...XX.", "....XX..", "...XX...", "..XX....", "..XX....", "..XX....", "........"],
    "8": [".XXXXX..", "XX...XX.", "XX...XX.", ".XXXXX..", "XX...XX.", "XX...XX.", ".XXXXX..", "........"],
    "9": [".XXXXX..", "XX...XX.", "XX...XX.", ".XXXXXX.", ".....XX.", "....XX..", ".XXXX...", "........"],
    "A": ["..XXX...", ".XX.XX..", "XX...XX.", "XX...XX.", "XXXXXXX.", "XX...XX.", "XX...XX.", "........"],
    "B": ["XXXXXX..", "XX...XX.", "XX...XX.", "XXXXXX..", "XX...XX.", "XX...XX.", "XXXXXX..", "........"],
    "C": ["..XXXX..", ".XX..XX.", "XX......", "XX......", "XX......", ".XX..XX.", "..XXXX..", "........"],
    "D": ["XXXXX...", "XX..XX..", "XX...XX.", "XX...XX.", "XX...XX.", "XX..XX..", "XXXXX...", "........"],
    "E": ["XXXXXXX.", "XX......", "XX......", "XXXXXX..", "XX......", "XX......", "XXXXXXX.", "........"],
    "F": ["XXXXXXX.", "XX......", "XX......", "XXXXXX..", "XX......", "XX......", "XX......", "........"],
    "R": ["XXXXXX..", "XX...XX.", "XX...XX.", "XXXXXX..", "XX.XX...", "XX..XX..", "XX...XX.", "........"],
    "Y": ["XX...XX.", "XX...XX.", ".XX.XX..", "..XXX...", "..XXX...", "..XXX...", "..XXX...", "........"],
    "+": ["........", "...XX...", "...XX...", ".XXXXXX.", ".XXXXXX.", "...XX...", "...XX...", "........"],
    "=": ["........", "XXXXXXX.", "XXXXXXX.", "........", "XXXXXXX.", "XXXXXXX.", "........", "........"],
}


def tile(rows: list[int]) -> bytes:
    """Eight rows of bits as one NES tile: plane 0 (colour 1), plane 1 empty."""
    return bytes(rows) + bytes(8)


def main() -> None:
    chr_ = bytearray(8192)
    for k, ch in enumerate(GLYPHS):
        rows = DRAW[ch]
        assert len(rows) == 8 and all(len(r) == 8 for r in rows), ch
        big = []  # 16 rows of 16 bits: every pixel doubled across and down
        for r in rows:
            bits = 0
            for c in r:
                bits = (bits << 2) | (3 if c == "X" else 0)
            big += [bits, bits]
        quarters = [
            [(b >> 8) & 255 for b in big[:8]],
            [b & 255 for b in big[:8]],
            [(b >> 8) & 255 for b in big[8:]],
            [b & 255 for b in big[8:]],
        ]
        for q, rows8 in enumerate(quarters):
            t = 1 + 4 * k + q
            chr_[t * 16:(t + 1) * 16] = tile(rows8)
    open(sys.argv[1], "wb").write(chr_)


if __name__ == "__main__":
    main()
