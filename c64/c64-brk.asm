; The C64's KERNAL reads the break bit straight from the stack page. Typed at the READY prompt: SYS 49152.
; This routine points the KERNAL's BRK vector ($0316) at our "show" routine and runs a BRK. The 6502 pushes the
; return address and the status byte and jumps through $FFFE to the KERNAL's handler at $FF48, which pushes A, X and Y,
; then (TSX / LDA $0104,X / AND #$10 at $FF4D-$FF51) reads the status byte BRK wrote and tests bit 4: set, so it jumps
; through $0316, here. "show" reads the same byte from the same place and prints it: STACKED P = 30 (bits 5 and 4,
; no flags). Then it takes the KERNAL's three bytes off, returns with RTI past the BRK, puts the vector back and
; returns to BASIC, which prints READY. Our own program. Build: python build.py (dasm).

        processor 6502

CHROUT  = $ffd2
CBINV   = $0316                 ; the KERNAL's BRK vector (default $FE66)

        org $c000
start   lda #<show
        sta CBINV
        lda #>show
        sta CBINV+1
        lda #$01                ; N and Z clear (C, V, D and I are clear from SYS's $030F = 0): every flag clear,
        brk                     ; C00C   so the status byte BRK pushes holds only what BRK sets itself
        .byte $ea               ; the byte BRK skips (its "signature" byte)
back    lda #$66                ; C00E: RTI comes back here; the vector as it was
        sta CBINV
        lda #$fe
        sta CBINV+1
        rts                     ; to SYS's $E146 + 1, and BASIC

show    tsx                     ; the stack: Y, X, A (pushed by the KERNAL), then P, PCL, PCH (pushed by BRK)
        lda $0104,x             ; the byte the KERNAL tested at $FF4E
        pha
        ldy #0
.t      lda text,y
        beq .h
        jsr CHROUT
        iny
        bne .t
.h      pla
        pha
        lsr
        lsr
        lsr
        lsr
        jsr hexout
        pla
        and #$0f
        jsr hexout
        lda #$0d
        jsr CHROUT
        pla                     ; the KERNAL's Y, X, A
        tay
        pla
        tax
        pla
        rti                     ; to $C00E, past the BRK and its signature byte

hexout  cmp #10
        bcc .d
        adc #6                  ; carry set: +7 -> "A"-"F"
.d      adc #$30
        jmp CHROUT

text    .byte $53,$54,$41,$43,$4b,$45,$44,$20,$50,$20,$3d,$20,$24,0   ; STACKED P = $
