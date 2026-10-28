; Double-size text in the C64's own font (each glyph's bits doubled across and down into four characters).
; Included by c64-jam, c64-jmpind, c64-lax and c64-rasterack (c64-decimal and c64-irqmask carry their own copy).
; The including program defines SCREEN, CHARSET, BIGBASE ($80: up to 32 glyphs), zp, zq,
; and glyphs/NGLYPH (the screen codes it uses). bigat: A = screen row of the top half, col = screen column,
; X/Y = the text (screen codes, 0-terminated), low and high byte.

; big text (screen codes, 0-terminated) at big row A, column in col
bigtext
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

row     .byte 0
col     .byte 0
idx     .byte 0
gi      .byte 0
src     .byte 0
dr      .byte 0
sy      .byte 0
