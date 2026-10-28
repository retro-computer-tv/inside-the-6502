; The indirect jump at an FF boundary, the film's own example on a Commodore 64's 6510:
; JMP ($02FF) at $0200, the pointer's low byte $34 at $02FF and its high byte $03 at $0300, so a programmer expects
; $0334. The screen shows the instruction and the three bytes involved; two seconds later the program runs the JMP.
; The NMOS 6502 takes the pointer's high byte from $0200, not $0300 (it adds one to the low byte only), and $0200
; holds the JMP's own opcode, $6C: the jump arrives at $6C34, whose routine prints ARRIVED AT 6C34. A routine at $0334
; would print ARRIVED AT 0334; it never runs. KERNAL and BASIC are banked out ($01 = $35), interrupts off, because
; $0300 is BASIC's error vector. Our own program; the font is the C64's own, doubled. Build: python build.py (dasm).

        processor 6502

SCREEN  = $0400
CHARSET = $3000
BIGBASE = $80
CHROUT  = $ffd2
zp      = $fb
zq      = $fd
WAIT    = 100                   ; two seconds (frames) before the jump

        org $0801
        .word basend, 10        ; 10 SYS2061
        .byte $9e, "2061", 0
basend  .word 0

start   lda #147                ; clear the screen (KERNAL still in)
        jsr CHROUT
        jsr makefont
        lda #$1c                ; screen $0400, characters $3000
        sta $d018
        sei
        lda #$7f                ; no CIA interrupts
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #$35                ; RAM under BASIC and KERNAL, I/O in
        sta $01
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #$6c                ; $0200: JMP ($02FF) = 6C FF 02
        sta $0200
        lda #$ff
        sta $0201
        lda #$02
        sta $0202
        lda #$34                ; the pointer: low byte at $02FF
        sta $02ff
        lda #$03                ; high byte at $0300
        sta $0300
        lda #$4c                ; $0334 (where a programmer expects to arrive): JMP expected
        sta $0334
        lda #<expected
        sta $0335
        lda #>expected
        sta $0336
        lda #$4c                ; $6C34 (where the 6502 arrives): JMP actual
        sta $6c34
        lda #<actual
        sta $6c35
        lda #>actual
        sta $6c36
        lda #10                 ; "JMP (02FF)"
        sta col
        lda #2
        ldx #<tjmp
        ldy #>tjmp
        jsr bigat
        lda #11                 ; "0200 = 6C", "02FF = 34", "0300 = 03"
        sta col
        lda #7
        ldx #<t0200
        ldy #>t0200
        jsr bigat
        lda #11
        sta col
        lda #10
        ldx #<t02ff
        ldy #>t02ff
        jsr bigat
        lda #11
        sta col
        lda #13
        ldx #<t0300
        ldy #>t0300
        jsr bigat
        ldx #WAIT
        jsr frames
go      jmp $0200

expected lda #<tok              ; reached through $0334: never, on an NMOS 6502
        ldx #>tok
        jmp arrived
actual  lda #<tbad              ; reached through $6C34
        ldx #>tbad
arrived stx zp+1                ; bigat wants the text in X/Y
        tax
        ldy zp+1
        lda #5
        sta col
        lda #19
        jsr bigat
.end    jmp .end
nmi     rti

; wait X frames (the raster passing line 256)
frames
.f1     lda $d011
        bmi .f1
.f2     lda $d011
        bpl .f2
        dex
        bne .f1
        rts

        include "bigfont.asm"

glyphs  .byte $30,$32,$33,$34,$36,$39                   ; 0 2 3 4 6 9
        .byte $01,$03,$04,$05,$06                       ; A C D E F
        .byte $09,$0a,$0d,$10,$12,$14,$16               ; I J M P R T V
        .byte $28,$29,$3d                               ; ( ) =
NGLYPH  = . - glyphs
tjmp    .byte $0a,$0d,$10,$20,$28,$30,$32,$06,$06,$29,0 ; JMP (02FF)
t0200   .byte $30,$32,$30,$30,$20,$3d,$20,$36,$03,0     ; 0200 = 6C
t02ff   .byte $30,$32,$06,$06,$20,$3d,$20,$33,$34,0     ; 02FF = 34
t0300   .byte $30,$33,$30,$30,$20,$3d,$20,$30,$33,0     ; 0300 = 03
tok     .byte $01,$12,$12,$09,$16,$05,$04,$20,$01,$14,$20,$30,$33,$33,$34,0 ; ARRIVED AT 0334
tbad    .byte $01,$12,$12,$09,$16,$05,$04,$20,$01,$14,$20,$36,$03,$33,$34,0 ; ARRIVED AT 6C34
