; IRQ can be masked, NMI cannot: three counters on a Commodore 64, each ticking once a frame.
;   MAIN counts frames in the main loop (it polls the raster, no interrupt involved)
;   IRQ  counts interrupts from CIA 1's timer A, one a frame (the IRQ line)
;   NMI  counts interrupts from CIA 2's timer A, one a frame (the NMI line)
; For three seconds all run (CLI); then SEI: the IRQ counter stops while MAIN and NMI go on; then CLI: it
; resumes, now behind. The KERNAL and BASIC are banked out ($01 = $35) so the 6510's own vectors at $FFFA-$FFFF
; (in RAM) lead straight to our two handlers. Our own program; the font is the C64's own, doubled.
; Build: dasm c64-irqmask.asm -f1 -oc64-irqmask.prg

        processor 6502

SCREEN  = $0400
CHARSET = $3000
BIGBASE = $80                   ; this program never returns to BASIC, so codes $80-$FF are free
CHROUT  = $ffd2
zp      = $fb
zq      = $fd
PERIOD  = 19656 - 1             ; one PAL frame: 312 lines of 63 cycles

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

        ldx #150                ; three seconds with interrupts allowed
        jsr run
        sei                     ; mask IRQ
        lda #<txsei
        sta stat
        lda #>txsei
        sta stat+1
        ldx #150
        jsr run
        cli                     ; allow it again
        lda #<txcli
        sta stat
        lda #>txcli
        sta stat+1
        ldx #250
        jsr run
.end    jmp .end

; X frames of the main loop: wait for the frame, count it, show the three counters and the state
run     stx left
.frame  lda $d011
        bmi .frame
.wait   lda $d011
        bpl .wait
        inc mainc
        bne .m1
        inc mainc+1
.m1     ldx #<stattx            ; "SEI" or "CLI"
        ldy #>stattx
        jsr copystat
        lda #17                 ; the state, centred above the counters
        sta col
        lda #3
        ldx #<stattx
        ldy #>stattx
        jsr bigat
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

copystat lda stat
        sta zp
        lda stat+1
        sta zp+1
        ldy #3
.cs     lda (zp),y
        sta stattx,y
        dey
        bpl .cs
        rts

; a 16-bit counter (A high, X low) as four hex digits at big row Y, column 22
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


glyphs  .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39   ; 0-9
        .byte $01,$02,$03,$04,$05,$06                   ; A-F
        .byte $09,$0c,$0d,$0e,$11,$12,$13               ; I L M N Q R S
NGLYPH  = . - glyphs
lmain   .byte $0d,$01,$09,$0e,0                         ; MAIN
lirq    .byte $09,$12,$11,$20,0                         ; IRQ
lnmi    .byte $0e,$0d,$09,$20,0                         ; NMI
txsei   .byte $13,$05,$09,0                             ; SEI
txcli   .byte $03,$0c,$09,0                             ; CLI
stattx  .byte 0,0,0,0
num     .byte 0,0,0,0,0
stat    .word 0
mainc   .word 0
irqc    .word 0
nmic    .word 0
left    .byte 0
row     .byte 0
col     .byte 0
idx     .byte 0
gi      .byte 0
src     .byte 0
dr      .byte 0
sy      .byte 0
