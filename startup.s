; definitions
PPU_CTRL      = $2000
PPU_MASK      = $2001
PPU_STATUS    = $2002
OAM_ADDRESS   = $2003
PPU_ADDR      = $2006
PPU_DATA      = $2007
OAM_DMA       = $4014
APU_DMC       = $4010
APU_STATUS    = $4015
CONTROLLER    = $4016
APU_FRAME_CTR = $4017

BTN_A         = %10000000
BTN_B         = %01000000
BTN_SELECT    = %00100000
BTN_START     = %00010000
BTN_UP        = %00001000
BTN_DOWN      = %00000100
BTN_LEFT      = %00000010
BTN_RIGHT     = %00000001

  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 0

  .bank 0
  .org $C000

  .rsset $00
buttons .rs 1
pointerLo .rs 1
pointerHi .rs 1
temp1 .rs 1
temp2 .rs 1
seed .rs 2
clock .rs 2

vblank_wait:
  BIT PPU_STATUS
  BPL vblank_wait
  RTS

start:
  LDA #%10000000
  STA PPU_MASK
  SEI ; Ignore IRQs
  CLD ; Disable decimal mode

  ; Disable APU Frame IRQs
  LDX #$40
  STX APU_FRAME_CTR

  ; Setup stack
  LDX #$ff
  TXS

  INX ; x = $00
  STX PPU_CTRL ; Disable NMI
  STX PPU_MASK ; Disable rendering
  STX APU_DMC ; Disable DMC IRQs

  ; If the user presses reset during vblank, the PPU may reset
  ; with the vblank flag still true. This has about a 1 in 13
  ; chance of happening on NTSC or 2 in 9 on PAL. Clear the
  ; flag now so the vblankwait1 loop sees an actual vblank.
  BIT PPU_STATUS

  ; First of two waits for vertical blank to make sure that the
  ; PPU has stabilized
  JSR vblank_wait

  ; We now have about 30,000 cycles to burn before the PPU stabilizes.

  STX APU_STATUS ; Disable music channels

  ; We'll fill RAM with $00
  TXA
clear_ram:
  STA $00, X
  STA $0100, X
  STA $0300, X
  STA $0400, X
  STA $0500, X
  STA $0600, X
  ; STA $0700, X ; Remove this if you're storing reset-persistent data

  ;We skipped $0200, x on purpose. Usually, RAMP page 2 is used for the
  ; display list  t o be copied to OAM. OAM needs to be initialized to
  ; $ef-$ff, not 0, or we'll get a bunch of garbage sprites at (0, 0).

  INX
  BNE clear_ram

  ; Initialize OAM data in $0200 to have all y coordinates off-screen
  ; (e.g. set every fourth byte starting at $0200 to $ef)
  LDA #$ef
clear_oam:
  STA $0200, X

  INX
  INX
  INX
  INX
  BNE clear_oam

  ; Second of two waits for vertical blank to make sure that the
  ; PPU has stabilized
  JSR vblank_wait

  ; Initialize PPU OAM
  STX OAM_ADDRESS ; $00
  LDA #$02 ; use page $0200-$02ff
  STA OAM_DMA

  LDA PPU_STATUS ; Reset the PPU latch

  JMP startup

ReadCtrl:
  LDA #$01
  STA CONTROLLER
  LDA #$00
  STA CONTROLLER

  LDX #$08
  LDA #$00
  STA buttons
ReadCtrlLoop:
  LDA CONTROLLER
  LSR A
  ROL buttons
  DEX
  BNE ReadCtrlLoop

  RTS

; prng
;
; Returns a random 8-bit number in A (0-255), clobbers Y (0).
;
; Requires a 2-byte value on the zero page called "seed".
; Initialize seed to any value except 0 before the first call to prng.
; (A seed value of 0 will cause prng to always return 0.)
;
; This is a 16-bit Galois linear feedback shift register with polynomial $0039.
; The sequence of numbers it generates will repeat after 65535 calls.
;
; Execution time is an average of 125 cycles (excluding jsr and rts)
RAND:
  LDY #8
  LDA seed+0
R1:
  ASL A
  ROL seed+1
  BCC R2
  EOR #$39
R2:
  DEY
  BNE R1
  STA seed+0
  CMP #0
  RTS

NEG:
  EOR #$FF
  CLC
  ADC #$01
  RTS

; INTERRUPT VECTORS 

  .bank 1
  .org $FFFA
  .dw nmi
  .dw start
  .dw 0
