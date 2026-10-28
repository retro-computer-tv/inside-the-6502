; Acknowledging a raster interrupt with DEC $D019: the VIC-II sets bit 0 of $D019 when the raster reaches
; the line in $D012, and keeps asking for the processor's attention (its IRQ line held low) until a one is written
; back to that bit. Our program's interrupt fires at line 132 and changes one colour register ($D022, the multicolour
; that fills the box in the middle of the screen) to light red; the next fires at line 172 and changes it back, so a
; steady band runs across the box. Each write lands in the right border, so the band's edges are clean. Outside the box
; nothing uses $D022, so only the box can change. The main program counts frames on screen (MAIN).
; Built twice (build.py), the two programs differ only in the handler's acknowledgement:
;   ACK = 0: DEC $D019. It reads $F1, writes $F1 back unchanged (bit 0 still one: this write clears the interrupt),
;            then writes $F0.
;   ACK = 1: the final value only: LDA $D019 / SEC / SBC #1 / STA $D019 writes $F0 once, with bit 0 zero, which
;            clears nothing. The interrupt stays asserted, the handler is entered again as soon as it returns, the
;            box fills with stripes and the main program never runs again (MAIN stays at 0000).
; KERNAL and BASIC banked out ($01 = $35), so the 6510's vectors in RAM lead to our handler. Our own program; the font
; is the C64's own, doubled. Build: python build.py (dasm).

        processor 6502

SCREEN  = $0400
CHARSET = $3000
BIGBASE = $80                   ; this program never returns to BASIC, so codes $80-$FF are free
CHROUT  = $ffd2
zp      = $fb
zq      = $fd
BOXCHR  = $7f                   ; a character of multicolour pixels "01": all $D022
BASECOL = 14                    ; light blue
BANDCOL = 10                    ; light red
LINE1   = 132                   ; band on (not a badline: 132 & 7 = 4)
LINE2   = 172                   ; band off (172 & 7 = 4)

        org $0801
        .word basend, 10        ; 10 SYS2061
        .byte $9e, "2061", 0
basend  .word 0

start   lda #147                ; clear the screen (KERNAL still in)
        jsr CHROUT
        jsr makefont
        sei
        lda #$35                ; RAM under BASIC and KERNAL, I/O in
        sta $01
        lda #<irq
        sta $fffe
        lda #>irq
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #$7f                ; no CIA interrupts
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        ldx #7                  ; the box character: every pixel pair 01 (multicolour 1, $D022)
        lda #$55
.bc     sta CHARSET+BOXCHR*8,x
        dex
        bpl .bc
        ldx #0                  ; every cell white (colours 0-7 stay hi-res in multicolour mode)
        lda #1
.cr     sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne .cr
        lda #<(SCREEN+7*40+10)  ; the box: rows 7-17, columns 10-29, multicolour cells
        sta zp
        lda #>(SCREEN+7*40+10)
        sta zp+1
.br     ldx #19
.bx     txa
        pha
        tay
        lda #BOXCHR
        sta (zp),y
        lda zp+1                ; the colour RAM cell: same offset, $D800 page
        clc
        adc #>($d800-SCREEN)
        sta zp+1
        lda #8
        sta (zp),y
        lda zp+1
        sec
        sbc #>($d800-SCREEN)
        sta zp+1
        pla
        tax
        dex
        bpl .bx
        lda zp
        clc
        adc #40
        sta zp
        bcc .bn
        inc zp+1
.bn     inc boxrow
        lda boxrow
        cmp #11
        bne .br
        lda #COLTITLE           ; the title, the line of code, the counter's label
        sta col
        lda #1
        ldx #<ttitle
        ldy #>ttitle
        jsr bigat
        ldx #0
.cl     lda tcode,x
        beq .cd
        sta SCREEN+4*40+COLCODE,x
        inx
        bne .cl
.cd     lda #11
        sta col
        lda #20
        ldx #<tmain
        ldy #>tmain
        jsr bigat
        jsr showmain
        lda #$1c                ; screen $0400, characters $3000
        sta $d018
        lda #$18                ; multicolour characters, 40 columns
        sta $d016
        lda #6
        sta $d021               ; background blue
        lda #14
        sta $d020               ; border light blue
        lda #BASECOL
        sta $d022
        lda #$1b                ; screen on, raster bit 8 clear
        sta $d011
        lda #LINE1
        sta $d012
        lda #$01
        sta $d01a               ; raster interrupt on
        lda #$ff
        sta $d019               ; nothing pending
        lda #0
        sta phase
        cli

main
.f1     lda $d011               ; count frames (the raster passing line 256)
        bmi .f1
.f2     lda $d011
        bpl .f2
        inc mainc
        bne .m1
        inc mainc+1
.m1     jsr showmain
        jmp main

; the raster interrupt: alternately band on (line 132) and band off (line 172). It starts 7-14 cycles into the line;
; the colour is written 39 (on) or 41 (off) cycles after that, at cycle 46-55: in the right border, past the box
; (columns 10-29 end at cycle 46), so the band's edges are clean whatever the latency. No register but A is used.
irq     pha                     ; 3
        lda phase               ; 4
        eor #1                  ; 2
        sta phase               ; 4
        beq .off                ; 2, or 3 taken
        nop                     ; 9 x 2 = 18
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        lda #BANDCOL            ; 2
        sta $d022               ; 4: written on its last cycle
        lda #LINE2
        sta $d012
        jmp ack
.off    nop                     ; 8 x 2 + 3 = 19
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        bit $00
        lda #BASECOL
        sta $d022
        lda #LINE1
        sta $d012
ack
        IF ACK
        lda $d019               ; the final value only: $F1 - 1 = $F0, bit 0 zero
        sec
        sbc #1
        sta $d019
        ELSE
        dec $d019               ; read $F1, write $F1 (clears bit 0), write $F0
        ENDIF
        pla
        rti
nmi     rti

; MAIN's four hex digits at row 20, column 21
showmain lda mainc+1
        lsr
        lsr
        lsr
        lsr
        jsr hexcode
        sta num
        lda mainc+1
        and #$0f
        jsr hexcode
        sta num+1
        lda mainc
        lsr
        lsr
        lsr
        lsr
        jsr hexcode
        sta num+2
        lda mainc
        and #$0f
        jsr hexcode
        sta num+3
        lda #21
        sta col
        lda #20
        ldx #<num
        ldy #>num
        jmp bigat

hexcode cmp #10
        bcc .dig
        sbc #9
        rts
.dig    ora #$30
        rts

        include "bigfont.asm"

glyphs  .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39   ; 0-9
        .byte $01,$02,$03,$04,$05,$06                   ; A-F
        .byte $09,$0c,$0d,$0e,$0f,$15,$16,$19,$24       ; I L M N O U V Y $
NGLYPH  = . - glyphs
        IF ACK
COLTITLE = 4
ttitle  .byte $06,$09,$0e,$01,$0c,$20,$16,$01,$0c,$15,$05,$20,$0f,$0e,$0c,$19,0 ; FINAL VALUE ONLY
COLCODE = 2
tcode   .byte $0c,$04,$01,$20,$24,$04,$30,$31,$39,$20,$3a,$20,$13,$05,$03,$20,$3a,$20  ; LDA $D019 : SEC :
        .byte $13,$02,$03,$20,$23,$31,$20,$3a,$20,$13,$14,$01,$20,$24,$04,$30,$31,$39,0 ; SBC #1 : STA $D019
        ELSE
COLTITLE = 11
ttitle  .byte $04,$05,$03,$20,$24,$04,$30,$31,$39,0     ; DEC $D019
COLCODE = 15
tcode   .byte $04,$05,$03,$20,$24,$04,$30,$31,$39,0     ; DEC $D019
        ENDIF
tmain   .byte $0d,$01,$09,$0e,0                         ; MAIN
num     .byte 0,0,0,0,0
mainc   .word 0
phase   .byte 0
boxrow  .byte 0
