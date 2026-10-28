; The same two decimal additions as c64-decimal.asm, done by the NES's Ricoh 2A03 and printed in our own
; double-size font (nes-font.py). The 2A03's 6502 core has no working decimal correction (Quietust's die
; investigation), so SED sets the flag but the sums stay binary.
;   SED  CLC  LDA #$19  ADC #$28   -> $41, carry 0 on the 2A03
;   SED  CLC  LDA #$99  ADC #$01   -> $9A, carry 0
; Build: python build.py (dasm nes-decimal.asm -f3, then the iNES header, PRG and nes-font.py's CHR joined).
; NROM: 16 KB of program at $C000-$FFFF, 8 KB of tiles. Only nametable 0 is used.

        processor 6502

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007

        seg.u zeropage
        org $00
nmis    ds 1                    ; NMIs seen (one a frame)
result  ds 1
flags   ds 1
row     ds 1                    ; tile row of the text
col     ds 1                    ; tile column
ptr     ds 2
len     ds 1
addrhi  ds 1
addrlo  ds 1
answer  ds 3
carry   ds 8
top     ds 32                   ; the two tile rows of a line of big text, written in vertical blank
bot     ds 32

        seg code
        org $c000

reset   sei
        cld
        ldx #$ff
        txs
        inx
        stx PPUCTRL             ; no NMI, no rendering while the screen is set up
        stx PPUMASK
        bit PPUSTATUS
.vb1    bit PPUSTATUS           ; the PPU needs two frames after power-on
        bpl .vb1
        txa
.clr    sta $00,x
        sta $0200,x
        inx
        bne .clr
.vb2    bit PPUSTATUS
        bpl .vb2
        lda #$3f                ; palette
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #0
.pal    lda palette,x
        sta PPUDATA
        inx
        cpx #32
        bne .pal
        lda #$20                ; nametable 0 and its attributes: all blank
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldy #4
        ldx #0
        lda #0
.nt     sta PPUDATA
        inx
        bne .nt
        dey
        bne .nt
        jsr scroll0
        lda #$0a                ; show the background, the left 8 pixels too
        sta PPUMASK
        ldx #30
        jsr frames

        lda #<line1             ; "19 + 28 ="
        ldx #>line1
        ldy #8
        jsr bigtext
        ldx #60
        jsr frames
        sed
        clc
        lda #$19
add1    adc #$28                ; the addition the film is about
        sta result
        php
        pla
        sta flags
        cld
        lda #8
        jsr showsum

        lda #<line2             ; "99 + 01 ="
        ldx #>line2
        ldy #16
        jsr bigtext
        ldx #60
        jsr frames
        sed
        clc
        lda #$99
add2    adc #$01
        sta result
        php
        pla
        sta flags
        cld
        lda #16
        jsr showsum
forever jmp forever

nmi     inc nmis
irq     rti

; wait X frames
frames  lda nmis
.fw     cmp nmis
        beq .fw
        dex
        bne frames
        rts

scroll0 lda #$80                ; NMI on, nametable 0, tiles from pattern table 0
        sta PPUCTRL
        lda #0
        sta PPUSCROLL
        sta PPUSCROLL
        rts

; result and carry for the line at tile row A: the answer at column 24, "CARRY n" three tile rows down
showsum sta row
        lda result
        lsr
        lsr
        lsr
        lsr
        jsr hexchar
        sta answer
        lda result
        and #$0f
        jsr hexchar
        sta answer+1
        lda #0
        sta answer+2
        lda #24
        sta col
        lda #<answer
        ldx #>answer
        ldy row
        jsr bigat
        ldx #25
        jsr frames
        ldx #7
.cc     lda carrytx,x
        sta carry,x
        dex
        bpl .cc
        lda flags
        and #1
        ora #$30                ; "0" or "1"
        sta carry+6
        lda row
        clc
        adc #3
        tay
        lda #<carry
        ldx #>carry
        jsr bigtext
        ldx #75
        jsr frames
        rts

hexchar cmp #10                 ; 0-15 to ASCII
        bcc .d
        adc #$36                ; carry is set: 10 + $37 = "A"
        rts
.d      ora #$30
        rts

; big text: string at A (low) X (high), 0-terminated ASCII, at tile row Y from column 4
bigtext pha
        lda #4
        sta col
        pla
bigat   sta ptr
        stx ptr+1
        sty row
        lda row                 ; nametable address $2000 + row*32 + col
        lsr
        lsr
        lsr
        ora #$20
        sta addrhi
        lda row
        and #7
        asl
        asl
        asl
        asl
        asl
        ora col
        sta addrlo
        ldy #0
        ldx #0
.next   lda (ptr),y
        beq .built
        jsr quarter             ; A = first tile of the glyph, or 0 for a space
        cmp #0
        sta top,x
        beq .sp1
        clc
        adc #1
.sp1    sta top+1,x
        beq .sp2
        clc
        adc #1
.sp2    sta bot,x
        beq .sp3
        clc
        adc #1
.sp3    sta bot+1,x
        inx
        inx
        iny
        bne .next
.built  stx len
        lda nmis                ; write in the next vertical blank
.wv     cmp nmis
        beq .wv
        lda addrhi
        sta PPUADDR
        lda addrlo
        sta PPUADDR
        ldx #0
.wt     lda top,x
        sta PPUDATA
        inx
        cpx len
        bne .wt
        lda addrlo              ; the row below: +32
        clc
        adc #32
        tay
        lda addrhi
        adc #0
        sta PPUADDR
        sty PPUADDR
        ldx #0
.wb     lda bot,x
        sta PPUDATA
        inx
        cpx len
        bne .wb
        jsr scroll0
        rts

; ASCII A -> first tile of its glyph (1 + 4k, GLYPHS order in nes-font.py); a space -> 0. Keeps X and Y.
quarter cmp #$20
        beq .space
        sty len
        ldy #0
.find   cmp glyphs,y
        beq .got
        iny
        cpy #NGLYPH
        bne .find
        ldy len
.space  lda #0
        rts
.got    tya
        asl
        asl
        clc
        adc #1
        ldy len
        rts

glyphs  .byte "0123456789ABCDEFRY+="
NGLYPH  = . - glyphs
line1   .byte "19 + 28 =", 0
line2   .byte "99 + 01 =", 0
carrytx .byte "CARRY 0", 0
palette .byte $0f,$30,$30,$30, $0f,$30,$30,$30, $0f,$30,$30,$30, $0f,$30,$30,$30
        .byte $0f,$30,$30,$30, $0f,$30,$30,$30, $0f,$30,$30,$30, $0f,$30,$30,$30

        org $fffa
        .word nmi, reset, irq
