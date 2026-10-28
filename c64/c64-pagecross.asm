; One cycle made visible: an indexed load that crosses a page takes one cycle longer.
; A loop of exactly 63 cycles, one PAL raster line, draws a bar down the screen: each pass loads the bar's colour with
; LDA table,X and writes it to the border colour register, then writes the background colour back six cycles later.
; The screen is blanked (no badlines, nothing else on the bus), so the border fills the frame and one cycle is eight
; pixels. Built twice (build.py), the two programs differ only in the table's address and in the frame padding:
;   CROSS = 0: the table at $0200; X runs 0-119, so table+X never leaves page $02: every pass is 63 cycles and the bar
;              stays straight.
;   CROSS = 1: the table at $02B0; from X = $50 (line 80) table+X is $0300 and up, on the next page: the LDA takes
;              five cycles instead of four, each pass is 64, and the bar moves one cycle (8 pixels) right on every
;              line from there: it bends.
; After the 120 lines the padding brings every frame to exactly 19,656 cycles (312 lines of 63), so the picture stands
; still; the cross version's padding is 40 cycles shorter, giving back its 40 extra cycles. Each frame the program
; colours one more table entry, so the bar is drawn in one line at a time (the timing never changes, only the colour).
; KERNAL and BASIC banked out, every interrupt off. Our own program. Build: python build.py (dasm).

        processor 6502

LINES   = 120
BAR     = 1                     ; white
BG      = 6                     ; blue
FIRST   = 90                    ; the raster line of the first pass
        IF CROSS
BASE    = $02b0
        ELSE
BASE    = $0200
        ENDIF

        org $0801
        .word basend, 10        ; 10 SYS2061
        .byte $9e, "2061", 0
basend  .word 0

start   sei
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
        lda #0
        sta $d015               ; no sprites
        sta $d01a               ; no VIC-II interrupts
        sta reveal
        lda #$ff
        sta $d019
        ldx #0                  ; the table: every line the background colour to begin with
        lda #BG
.c      sta BASE,x
        inx
        cpx #LINES
        bne .c
        sta $d020
        lda #$0b                ; blank the screen: no badlines, the border colour everywhere
        sta $d011
.w1     lda $d012               ; once: wait for the line before the first pass, then 51 cycles, so the first pass
        cmp #FIRST-1            ; starts near the beginning of line FIRST and the bar near the left of the picture
        bne .w1
        ldy #9                  ; 46
.w2     dey
        bne .w2
        nop                     ; 5
        bit $00
        jmp frame
nmi     rti

        org $1000
frame   ldx #0                  ; 2
line    lda BASE,x              ; 4, or 5 when BASE+X is on the next page
        sta $d020               ; 4   the bar begins
        lda #BG                 ; 2
        sta $d020               ; 4   the bar ends (six cycles: 48 pixels)
        ldy #7                  ; 36  (2 + 7 x 5 - 1)
.d1     dey
        bne .d1
        nop                     ; 2
        nop                     ; 2
        nop                     ; 2
        inx                     ; 2
        cpx #LINES              ; 2
        bne line                ; 3 (2 when the loop ends)   = 63 a pass
; one more table entry coloured each frame (19 cycles whatever Y is)
        ldy reveal              ; 4
        lda #BAR                ; 2
        sta BASE,y              ; 5 (an indexed store always takes 5)
        lda nexttab,y           ; 4 (nexttab starts a page: never crosses)
        sta reveal              ; 4
; padding: 19,656 - 23 - 120 x 63 - crossings = 12,073 - crossings
        ldx #9                  ; 11,530 = 2 + 9 x 1,281 - 1
.o      ldy #255
.i      dey
        bne .i
        dex
        bne .o
        IF CROSS
        ldy #100                ; 501 + 2 = 503 = 12,033 - 11,530 (40 crossings)
        ELSE
        ldy #108                ; 541 + 2 = 543 = 12,073 - 11,530
        ENDIF
.r      dey
        bne .r
        nop
        jmp frame               ; 3
        IF * > $10ff
        ERR                     ; every branch must stay on page $10
        ENDIF

        org $1100
nexttab                         ; Y + 1, stopping at the last line
I       SET 0
        REPEAT LINES
        IF I < LINES - 1
        .byte I + 1
        ELSE
        .byte I
        ENDIF
I       SET I + 1
        REPEND

        org $1200
reveal  .byte 0
