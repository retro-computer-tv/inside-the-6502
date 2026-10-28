; JAM stops the processor: the three counters of c64-irqmask (MAIN, IRQ, NMI, one tick a frame
; each, the same screen layout) run for four seconds with interrupts allowed; then the main program prints JAM on its
; state line and runs the opcode $02. After it nothing counts: not the main loop, not the IRQ from CIA 1's timer, not
; the NMI from CIA 2's timer, the one interrupt software cannot mask. The VIC-II keeps drawing the last picture.
; Only a reset brings the C64 back, to its start-up screen.
; KERNAL and BASIC are banked out ($01 = $35), so the 6510's own vectors in RAM lead straight to our handlers.
; Our own program; the font is the C64's own, doubled. Build: python build.py (dasm).

        processor 6502

SCREEN  = $0400
CHARSET = $3000
BIGBASE = $80                   ; this program never returns to BASIC, so codes $80-$FF are free
CHROUT  = $ffd2
zp      = $fb
zq      = $fd
PERIOD  = 19656 - 1             ; one PAL frame: 312 lines of 63 cycles
RUNFRAMES = 200                 ; four seconds before the JAM

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
        lda #$35                ; RAM under BASIC and KERNAL, I/O in
        sta $01
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #<irq
        sta $fffe
        lda #>irq
        sta $ffff
        lda #0
        sta $d01a               ; no VIC-II interrupts
        lda #$7f
        sta $dc0d               ; CIA interrupts off, pending ones cleared
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #<PERIOD
        sta $dc04
        sta $dd04
        lda #>PERIOD
        sta $dc05
        sta $dd05
        lda #$81
        sta $dc0d               ; CIA 1 timer A -> IRQ
        sta $dd0d               ; CIA 2 timer A -> NMI
        lda #$11                ; start both, continuous
        sta $dc0e
        sta $dd0e
        jsr labels3
        lda #<txcli
        sta stat
        lda #>txcli
        sta stat+1
        cli

        ldx #RUNFRAMES          ; four seconds with interrupts allowed
        jsr run
        lda #<txjam             ; the state line says what runs next
        sta stat
        lda #>txjam
        sta stat+1
        jsr showstat
jamop   .byte $02               ; JAM
        jmp jamop               ; never reached

; X frames of the main loop: wait for the frame, count it, show the three counters and the state
run     stx left
.frame  lda $d011
        bmi .frame
.wait   lda $d011
        bpl .wait
        inc mainc
        bne .m1
        inc mainc+1
.m1     jsr showstat
        lda mainc+1
        ldx mainc
        ldy #9
        jsr shownum
        lda irqc+1
        ldx irqc
        ldy #13
        jsr shownum
        lda nmic+1
        ldx nmic
        ldy #17
        jsr shownum
        dec left
        bne .frame
        rts

showstat lda stat               ; the state ("CLI", "JAM"), centred above the counters
        sta zp
        lda stat+1
        sta zp+1
        ldy #3
.cs     lda (zp),y
        sta stattx,y
        dey
        bpl .cs
        lda #17
        sta col
        lda #3
        ldx #<stattx
        ldy #>stattx
        jmp bigat

; a 16-bit counter (A high, X low) as four hex digits at screen row Y, column 22
shownum sty row
        pha
        lsr
        lsr
        lsr
        lsr
        jsr hexcode
        sta num
        pla
        and #$0f
        jsr hexcode
        sta num+1
        txa
        lsr
        lsr
        lsr
        lsr
        jsr hexcode
        sta num+2
        txa
        and #$0f
        jsr hexcode
        sta num+3
        lda #22
        sta col
        lda row
        ldx #<num
        ldy #>num
        jmp bigat

hexcode cmp #10
        bcc .dig
        sbc #9
        rts
.dig    ora #$30
        rts

labels3 lda #6                  ; MAIN, IRQ, NMI at column 6 of rows 9, 13, 17
        sta col
        lda #9
        ldx #<lmain
        ldy #>lmain
        jsr bigat
        lda #6
        sta col
        lda #13
        ldx #<lirq
        ldy #>lirq
        jsr bigat
        lda #6
        sta col
        lda #17
        ldx #<lnmi
        ldy #>lnmi
        jmp bigat

irq     inc irqc                ; the IRQ handler: count, acknowledge CIA 1
        bne .i1
        inc irqc+1
.i1     bit $dc0d
        rti

nmi     inc nmic                ; the NMI handler: count, acknowledge CIA 2
        bne .n1x
        inc nmic+1
.n1x    bit $dd0d
        rti

        include "bigfont.asm"

glyphs  .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39   ; 0-9
        .byte $01,$02,$03,$04,$05,$06                   ; A-F
        .byte $09,$0a,$0c,$0d,$0e,$11,$12,$13           ; I J L M N Q R S
NGLYPH  = . - glyphs
lmain   .byte $0d,$01,$09,$0e,0                         ; MAIN
lirq    .byte $09,$12,$11,$20,0                         ; IRQ
lnmi    .byte $0e,$0d,$09,$20,0                         ; NMI
txcli   .byte $03,$0c,$09,0                             ; CLI
txjam   .byte $0a,$01,$0d,0                             ; JAM
stattx  .byte 0,0,0,0
num     .byte 0,0,0,0,0
stat    .word 0
mainc   .word 0
irqc    .word 0
nmic    .word 0
left    .byte 0
