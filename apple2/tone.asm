; One tone loop for the original Apple II, assembled twice by build.py: at $0300, where its branch stays inside page
; $03, and at $0CF8, where the same branch (at $0CFE) is taken from $0D00, the address after it, back to $0CFD in page
; $0C: a page crossing, one more cycle on every taken branch. Only the JMP's two address bytes differ.
; Each pass reads the speaker soft switch once ($C030: every access flips the speaker), so one pass is half a period:
;   LDA $C030 4 + LDX #$64 2 + 99 x (DEX 2 + BNE taken 3 or 4) + DEX 2 + BNE not taken 2 + JMP 3
;   = 508 cycles (no crossing) or 607 (crossing).
; ORIGIN is given on dasm's command line (-DORIGIN=...).
        processor 6502
        org ORIGIN
TONE    lda $C030       ; click the speaker
        ldx #$64        ; 100 passes of the inner loop
WAIT    dex
        bne WAIT        ; taken 99 times
        jmp TONE
