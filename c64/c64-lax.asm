; One undocumented instruction loads A and X at once. The bytes AF 00 C0 (opcode AF, which no MOS
; data sheet lists; usually called LAX absolute) with $C000 = $42. The screen shows the instruction's bytes and the
; memory byte, then A and X as they are (both 00); two seconds later the program runs the one instruction and shows
; A and X again: both 42. Our own program; the font is the C64's own, doubled. Build: python build.py (dasm).

        processor 6502

SCREEN  = $0400
CHARSET = $3000
BIGBASE = $80
CHROUT  = $ffd2
zp      = $fb
zq      = $fd
WAIT    = 100                   ; two seconds (frames) before the instruction runs

        org $0801
        .word basend, 10        ; 10 SYS2061
        .byte $9e, "2061", 0
basend  .word 0

start   lda #147                ; clear the screen (KERNAL still in)
        jsr CHROUT
        jsr makefont
        lda #$1c                ; screen $0400, characters $3000
        sta $d018
        lda #$42                ; the byte in memory
        sta $c000
        lda #12                 ; "AF 00 C0", the instruction's three bytes
        sta col
        lda #4
        ldx #<tins
        ldy #>tins
        jsr bigat
        lda #11                 ; "C000 = 42"
        sta col
        lda #9
        ldx #<tmem
        ldy #>tmem
        jsr bigat
        lda #0                  ; A and X before: both zero
        sta aval
        sta xval
        jsr showax
        ldx #WAIT
        jsr frames
        lda #0
        ldx #0
lax     .byte $af, $00, $c0     ; LAX $C000: A and X both loaded from $C000
after   sta aval
        stx xval
        jsr showax
.end    jmp .end

; "A = nn  X = nn" at row 15
showax  lda aval
        ldx #4
        jsr hex2
        lda xval
        ldx #12
        jsr hex2
        lda #6
        sta col
        lda #15
        ldx #<tax
        ldy #>tax
        jmp bigat

; A as two hex digits (screen codes) into tax at offset X
hex2    pha
        lsr
        lsr
        lsr
        lsr
        jsr hexcode
        sta tax,x
        pla
        and #$0f
        jsr hexcode
        sta tax+1,x
        rts

hexcode cmp #10
        bcc .dig
        sbc #9
        rts
.dig    ora #$30
        rts

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

glyphs  .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39   ; 0-9
        .byte $01,$02,$03,$04,$05,$06                   ; A-F
        .byte $18,$3d                                   ; X =
NGLYPH  = . - glyphs
tins    .byte $01,$06,$20,$30,$30,$20,$03,$30,0         ; AF 00 C0
tmem    .byte $03,$30,$30,$30,$20,$3d,$20,$34,$32,0     ; C000 = 42
tax     .byte $01,$20,$3d,$20,$30,$30,$20,$20           ; A = 00
        .byte $18,$20,$3d,$20,$30,$30,0                 ;   X = 00
aval    .byte 0
xval    .byte 0
