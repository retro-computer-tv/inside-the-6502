; BASIC calls machine code and carries on. Typed at the READY prompt:
;   10 PRINT "BEFORE"
;   20 SYS 49152
;   30 PRINT "AFTER"
;   RUN
; SYS 49152 jumps to this routine at $C000 after pushing $E146 on the stack, one less than where BASIC wants to come
; back ($E147), because RTS adds one. The routine prints A, B, C and a RETURN through the KERNAL's CHROUT: its
; JSR $FFD2 (at $C005-$C007) pushes $C007, the address of its own last byte, and CHROUT's RTS adds one and comes back
; to $C008. The routine's RTS takes $E146, adds one and lands at $E147, and BASIC carries on with line 30. The
; routine's 18 bytes are put at $C000 before the lines are typed (as if loaded from disk). Our own program.
; Build: python build.py (dasm).

        processor 6502

CHROUT  = $ffd2

        org $c000
start   ldx #0                  ; C000
loop    lda text,x              ; C002
        jsr CHROUT              ; C005: pushes $C007, its own last byte
        inx                     ; C008: where CHROUT's RTS lands
        cpx #4
        bne loop
        rts                     ; C00D: back to SYS's $E146 + 1
text    .byte $41,$42,$43,$0d   ; A B C RETURN (PETSCII)
