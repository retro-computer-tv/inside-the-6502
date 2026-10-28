; Two decimal additions, done by the Commodore 64's own 6510 and printed in double-size characters made from the C64's own font.
;   SED  CLC  LDA #$19  ADC #$28   -> $47, carry 0 on an NMOS 6502 core
;   SED  CLC  LDA #$99  ADC #$01   -> $00, carry 1
; Each sum is shown first, the addition runs a second later, and its result and carry appear; the program then
; returns to BASIC (READY.). Interrupts are masked around each addition, because the C64's IRQ handler does not
; clear decimal mode (an NMOS 6502 keeps D set when it takes an interrupt).
; Build: dasm c64-decimal.asm -f1 -oc64-decimal.prg

        processor 6502

SCREEN  = $0400
COLRAM  = $d800
CHARSET = $3000                 ; RAM copy of the character ROM, with the big glyphs added
BIGBASE = $a4                   ; first screen code used for big quarters ($a0, the cursor's block, is kept)
CHROUT  = $ffd2
PLOT    = $fff0
zp      = $fb                   ; two free zero-page pointers ($fb-$fe)
zq      = $fd

        org $0801
        .word basend, 10        ; 10 SYS2061
        .byte $9e, "2061", 0
basend  .word 0

start   lda #147                ; clear the screen (KERNAL)
        jsr CHROUT
        jsr makefont
        lda #$1c                ; screen at $0400, characters at $3000
        sta $d018

        ldx #<line1             ; "19 + 28 ="
        ldy #>line1
        lda #6
        jsr bigtext
        ldx #60
        jsr frames
        sei
        sed
        clc
        lda #$19
add1    adc #$28                ; the addition the film is about
        sta result
        php
        pla
        sta flags
        cld
        cli
        lda #6
        jsr showsum

        ldx #<line2             ; "99 + 01 ="
        ldy #>line2
        lda #13
        jsr bigtext
        ldx #60
        jsr frames
        sei
        sed
        clc
        lda #$99
add2    adc #$01
        sta result
        php
        pla
        sta flags
        cld
        cli
        lda #13
        jsr showsum

        ldx #21                 ; READY. below the sums
        ldy #0
        clc
        jsr PLOT
        rts

; result and carry for the line at big row A: "= 47" then "CARRY 0" three rows down
showsum sta row
        lda result
        lsr
        lsr
        lsr
        lsr
        jsr hexcode
        sta answer
        lda result
        and #$0f
        jsr hexcode
        sta answer+1
        ldx #<answer
        ldy #>answer
        lda #28                 ; column of the answer: 8 + 2 x 10 (two screen columns per big character)
        sta col
        lda row
        jsr bigat
        ldx #25
        jsr frames
        lda flags
        and #1
        ora #$30
        sta carry+6
        ldx #<carry
        ldy #>carry
        lda row
        clc
        adc #3
        jsr bigtext
        ldx #75
        jsr frames
        rts

hexcode cmp #10                 ; 0-15 to a screen code: digits $30-$39, A-F $01-$06
        bcc .dig
        sbc #9
        rts
.dig    ora #$30
        rts

; wait X frames (raster passes line 256 once a frame)
frames
.w1     lda $d011
        bmi .w1
.w2     lda $d011
        bpl .w2
        dex
        bne frames
        rts

; big text (screen codes, 0-terminated) at big row A, from column 8
bigtext pha
        lda #8
        sta col
        pla
bigat   stx zp
        sty zp+1
        tax
        lda rowlo,x
        sta zq
        lda rowhi,x
        sta zq+1
        lda zq                  ; zq = SCREEN + row*40 + col
        clc
        adc col
        sta zq
        bcc .n1
        inc zq+1
.n1     ldy #0
.next   lda (zp),y
        beq .done
        sty idx
        jsr quarter             ; A = first quarter's screen code, or $20 for a space
        ldy #0
        sta (zq),y
        cmp #$20
        beq .sp1
        clc
        adc #1
.sp1    iny
        sta (zq),y
        cmp #$20
        beq .sp2
        clc
        adc #1
.sp2    ldy #40
        sta (zq),y
        cmp #$20
        beq .sp3
        clc
        adc #1
.sp3    iny
        sta (zq),y
        lda zq                  ; two screen columns on
        clc
        adc #2
        sta zq
        bcc .n2
        inc zq+1
.n2     ldy idx
        iny
        bne .next
.done   rts

; screen code A -> first of its four quarter codes (glyph k uses BIGBASE + 4k .. +3); a space stays $20
quarter cmp #$20
        beq .q
        ldx #0
.find   cmp glyphs,x
        beq .got
        inx
        cpx #NGLYPH
        bne .find
        lda #$20
.q      rts
.got    txa
        asl
        asl
        clc
        adc #BIGBASE
        rts

; copy the 2K character ROM (upper case and graphics) to CHARSET, then draw each big glyph's four quarters:
; every source bit doubled across and every source row doubled down.
makefont sei
        lda $01
        pha
        and #$fb                ; character ROM in at $d000
        sta $01
        lda #$00
        sta zp
        sta zq
        lda #$d0
        sta zp+1
        lda #>CHARSET
        sta zq+1
        ldx #8
        ldy #0
.cp     lda (zp),y
        sta (zq),y
        iny
        bne .cp
        inc zp+1
        inc zq+1
        dex
        bne .cp
        ldx #0                  ; glyph index
.g      stx gi
        lda glyphs,x            ; source: $d000 + code*8
        sta zp
        lda #0
        sta zp+1
        asl zp
        rol zp+1
        asl zp
        rol zp+1
        asl zp
        rol zp+1
        lda zp+1
        ora #$d0
        sta zp+1
        txa                     ; destination: CHARSET + (BIGBASE + 4k)*8
        asl
        asl
        clc
        adc #BIGBASE
        sta zq
        lda #0
        sta zq+1
        asl zq
        rol zq+1
        asl zq
        rol zq+1
        asl zq
        rol zq+1
        lda zq+1
        clc
        adc #>CHARSET
        sta zq+1
        ldy #0                  ; source row 0-7
.r      lda (zp),y
        sta src
        tya
        and #3
        asl                     ; destination row within its quarter: (row mod 4) * 2
        sta dr
        tya
        and #4                  ; rows 4-7 go to the lower quarters (+16 bytes)
        asl
        asl
        ora dr
        sta dr
        lda src                 ; left half -> upper/lower left quarter
        lsr
        lsr
        lsr
        lsr
        tax
        lda dbl,x
        sty sy
        ldy dr
        sta (zq),y
        iny
        sta (zq),y
        lda src                 ; right half -> the quarter 8 bytes on
        and #$0f
        tax
        lda dbl,x
        pha
        lda dr
        clc
        adc #8
        tay
        pla
        sta (zq),y
        iny
        sta (zq),y
        ldy sy
        iny
        cpy #8
        bne .r
        ldx gi
        inx
        cpx #NGLYPH
        beq .gend
        jmp .g
.gend   pla
        sta $01
        cli
        rts

; a nibble with every bit doubled: abcd -> aabbccdd
dbl     .byte $00,$03,$0c,$0f,$30,$33,$3c,$3f,$c0,$c3,$cc,$cf,$f0,$f3,$fc,$ff

; quarter order in the character set: k*4+0 top left, +1 top right, +2 bottom left, +3 bottom right.
; makefont writes rows 0-3 of a glyph to +0 (left) and +1 (right), rows 4-7 to +2 and +3.
glyphs  .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39   ; 0-9
        .byte $01,$02,$03,$04,$05,$06                   ; A-F
        .byte $12,$19,$2b,$3d                           ; R Y + =
NGLYPH  = . - glyphs

line1   .byte $31,$39,$20,$2b,$20,$32,$38,$20,$3d,0     ; 19 + 28 =
line2   .byte $39,$39,$20,$2b,$20,$30,$31,$20,$3d,0     ; 99 + 01 =
carry   .byte $03,$01,$12,$12,$19,$20,$30,0             ; CARRY 0
answer  .byte 0,0,0

rowlo   .byte <(SCREEN+0*40),<(SCREEN+1*40),<(SCREEN+2*40),<(SCREEN+3*40),<(SCREEN+4*40)
        .byte <(SCREEN+5*40),<(SCREEN+6*40),<(SCREEN+7*40),<(SCREEN+8*40),<(SCREEN+9*40)
        .byte <(SCREEN+10*40),<(SCREEN+11*40),<(SCREEN+12*40),<(SCREEN+13*40),<(SCREEN+14*40)
        .byte <(SCREEN+15*40),<(SCREEN+16*40),<(SCREEN+17*40),<(SCREEN+18*40),<(SCREEN+19*40)
        .byte <(SCREEN+20*40),<(SCREEN+21*40),<(SCREEN+22*40),<(SCREEN+23*40)
rowhi   .byte >(SCREEN+0*40),>(SCREEN+1*40),>(SCREEN+2*40),>(SCREEN+3*40),>(SCREEN+4*40)
        .byte >(SCREEN+5*40),>(SCREEN+6*40),>(SCREEN+7*40),>(SCREEN+8*40),>(SCREEN+9*40)
        .byte >(SCREEN+10*40),>(SCREEN+11*40),>(SCREEN+12*40),>(SCREEN+13*40),>(SCREEN+14*40)
        .byte >(SCREEN+15*40),>(SCREEN+16*40),>(SCREEN+17*40),>(SCREEN+18*40),>(SCREEN+19*40)
        .byte >(SCREEN+20*40),>(SCREEN+21*40),>(SCREEN+22*40),>(SCREEN+23*40)

result  .byte 0
flags   .byte 0
row     .byte 0
col     .byte 0
idx     .byte 0
gi      .byte 0
src     .byte 0
dr      .byte 0
sy      .byte 0
