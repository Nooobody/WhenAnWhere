  .include "startup.s"

BALL = $0200
BALL_VEL = $02
BALL_START_Y = $A0
PADDLE = $0210
PADDLE_SPEED = $04
PADDLE_HEIGHT = $D8
TIME_SPR = $0224
SCORE_SPR = $0234

RIGHT_WALL = $E8
LEFT_WALL = $10
TOP_WALL = $20
BOTTOM_WALL = $E8

GAMESTATE_TITLE = $00
GAMESTATE_PLAYING = $01
GAMESTATE_GAMEOVER = $02

  .rsset $0010
gamestate .rs 1
ball_x .rs 1
ball_y .rs 1
ball_vel_x .rs 1
ball_vel_y .rs 1
time .rs 2
scoreOnes .rs 1
scoreTens .rs 1
scoreHundreds .rs 1

  .bank 0
  .org $C100

startup:

; Load title screen
; Screen is reset to 0, only load text
LoadTitle:
  ; Starts at $2000
  LDA #$20
  STA PPU_ADDR
  LDA #$89
  STA PPU_ADDR

  LDX #$00
LoadTitleLoop:
  LDA TitleData, X
  STA PPU_DATA
  INX
  CPX #$0D
  BNE LoadTitleLoop

  LDA #$22
  STA PPU_ADDR
  LDA #$0A
  STA PPU_ADDR

LoadTitleStartLoop:
  LDA TitleData, X
  STA PPU_DATA
  INX
  CPX #$18
  BNE LoadTitleStartLoop

LoadAttributeTable:
  LDA PPU_STATUS ; Reset the PPU latch

  ; Starts at $23C0
  LDA #$23
  STA PPU_ADDR
  LDA #$C0
  STA PPU_ADDR

  LDX #$00
LoadAttributeTableLoop:
  LDA #$00
  STA PPU_DATA
  INX
  CPX #$40
  BNE LoadAttributeTableLoop

LoadPalettes:
  LDA PPU_STATUS ; Reset the PPU latch

  LDA #$3F
  STA PPU_ADDR
  LDA #$10
  STA PPU_ADDR

  LDX #$00
LoadPalettesLoop:
  LDA PaletteData, X
  STA PPU_DATA
  INX
  CPX #$20
  BNE LoadPalettesLoop


  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK

  LDA #$00
  STA $2005
  STA $2005

  LDX #$00
LoadSprites:
  LDA SpriteData, X
  STA $0200, X
  INX
  CPX #$40
  BNE LoadSprites

  LDA #GAMESTATE_TITLE
  STA gamestate

  JMP main

AddScoreOne:
  LDA scoreOnes
  CLC
  ADC #$01
  STA scoreOnes
  ; Check if it's over 9
  CMP #$0A
  BNE ScoreDone
  LDA #$00
  STA scoreOnes
AddScoreTen:
  LDA scoreTens
  CLC
  ADC #$01
  STA scoreTens
  CMP #$0A
  BNE ScoreDone
  LDA #$00
  STA scoreTens
AddScoreHundreds:
  LDA scoreHundreds
  CLC
  ADC #$01
  STA scoreHundreds
  ; No overflow check, let it burn!!!

ScoreDone:
  LDX scoreOnes
  LDA NumberSprites, X
  STA SCORE_SPR+9
  LDX scoreTens
  LDA NumberSprites, X
  STA SCORE_SPR+5
  LDX scoreHundreds
  LDA NumberSprites, X
  STA SCORE_SPR+1
  RTS

Reset_Ball:
  LDX #$03
  JSR RAND
  ; Shift right and left to reset bit 0
  ; With non-zero bit 0, the ball clips through walls.
  ; When velocity != 1
  LSR A
  ASL A
  STA BALL, X
  STA ball_x
  LDA #BALL_START_Y
  STA ball_y

  LDA #BALL_VEL
  STA ball_vel_x
  JSR NEG
  STA ball_vel_y
  
  RTS

Negate_X_Vel:
  LDA ball_vel_x
  JSR NEG
  STA ball_vel_x
  RTS

Negate_Y_Vel:
  LDA ball_vel_y
  JSR NEG
  STA ball_vel_y
  RTS

Ball_Falls:
  JSR Reset_Ball
  RTS

StartGame:
  ; Turn off rendering while we're working
  LDA #%00010000
  STA PPU_CTRL
  LDA #%00000110
  STA PPU_MASK

  LDA clock+0
  STA seed+0
  LDA clock+1
  STA seed+1

  JSR Reset_Ball

  JSR RAND
  STA time+0
  JSR RAND
  STA time+1

  LDA time
  AND #$0F
  TAX
  LDA NumberSprites, X
  STA TIME_SPR+1

  LDA time
  ROL A
  ROL A
  ROL A
  ROL A
  AND #$0F
  TAX
  LDA NumberSprites, X
  STA TIME_SPR+5

  LDA time+1
  AND #$0F
  TAX
  LDA NumberSprites, X
  STA TIME_SPR+9

  LDA time+1
  ROL A
  ROL A
  ROL A
  ROL A
  AND #$0F
  TAX
  LDA NumberSprites, X
  STA TIME_SPR+13

  JSR LoadBackground
  LDA #GAMESTATE_PLAYING
  STA gamestate

  ; Turn NMI back on
  LDA #%10010000
  STA PPU_CTRL

  RTS

main:
  LDA gamestate
  CMP #GAMESTATE_TITLE
  BNE ClockDone
  LDA clock
  CLC
  ADC #$01
  STA clock
  LDA clock+1
  ADC #$00
  STA clock+1
ClockDone:
  JMP main

nmi:
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014

  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK

  JSR ReadCtrl

GameEngine:
  LDA gamestate
  CMP #GAMESTATE_TITLE
  BEQ GameEngine_Title
  CMP #GAMESTATE_PLAYING
  BEQ GameEngine_Playing
  CMP #GAMESTATE_GAMEOVER
  BEQ GameEngine_Gameover

GameEngine_Done:
  RTI

GameEngine_Title:
  LDA #%0001110
  STA PPU_MASK

  LDA buttons
  AND #BTN_START
  BEQ TitleStartKeyDone

  JSR StartGame

TitleStartKeyDone:

  JMP GameEngine_Done
GameEngine_Gameover:
  JMP GameEngine_Done


GameEngine_Playing:
Update_Ball_Pos:
  LDA ball_x
  CLC
  ADC ball_vel_x
  STA ball_x

  LDA ball_vel_x
  BMI Going_Left

Going_Right:
  LDA ball_x
  ADC #$08
  CMP #RIGHT_WALL
  BNE Check_Y_Pos
  JSR Negate_X_Vel
  JSR AddScoreOne
  JMP Check_Y_Pos

Going_Left:
  LDA ball_x
  CMP #LEFT_WALL
  BNE Check_Y_Pos
  JSR Negate_X_Vel
  JSR AddScoreOne

Check_Y_Pos:
  LDA ball_y
  CLC
  ADC ball_vel_y
  STA ball_y

  LDA ball_vel_y
  BMI Going_Up
Going_Down:
  LDA ball_y
  CLC
  ADC #$08
  CMP #PADDLE_HEIGHT ; Check paddle height
  BNE Check_Fall
  LDX #$03
  LDA ball_x
  CLC
  ADC #$08
  CMP PADDLE, X ; Check paddle left side
  BMI Check_Fall
  LDA ball_x
  LDX #$13
  CMP PADDLE, X ; Check paddle right side
  BPL Check_Fall
  ; WE HIT THE PADDLE!
  JSR Negate_Y_Vel
  JSR AddScoreTen
  JMP Update_Ball_Spr
  
Check_Fall:
  CMP #BOTTOM_WALL
  BNE Update_Ball_Spr
  ; We missed the paddle
  JSR Ball_Falls
  JMP Update_Ball_Spr

Going_Up:
  LDA ball_y
  CMP #TOP_WALL
  BNE Update_Ball_Spr
  JSR Negate_Y_Vel
  JSR AddScoreOne

Update_Ball_Spr:
  ; Top Left
  LDX #$03
  LDA ball_y
  STA BALL
  LDA ball_x
  STA BALL, X

  ; Top Right
  LDX #$04
  LDA ball_y
  STA BALL, X
  LDA ball_x
  CLC
  ADC #$08
  LDX #$07
  STA BALL, X

  ; Bottom Left
  LDX #$08
  LDA ball_y
  CLC
  ADC #$08
  STA BALL, X
  LDX #$0B
  LDA ball_x
  STA BALL, X

  ; Bottom Right
  LDX #$0C
  LDA ball_y
  CLC
  ADC #$08
  STA BALL, X
  LDX #$0F
  LDA ball_x
  CLC
  ADC #$08
  STA BALL, X


Update_Ball_Done:

  LDA buttons
  BEQ Controls_Done

  AND #BTN_LEFT
  BEQ Left_Done

  ;;; MOVE TO THE LEFT, CHECK FOR WALL
  LDX #$3
  LDA PADDLE, X
  CMP #LEFT_WALL
  BEQ Left_Done

  LDX #$13
Left_Down:
  LDA PADDLE, X
  SEC
  SBC #PADDLE_SPEED
  STA PADDLE, X
  DEX
  DEX
  DEX
  DEX
  BPL Left_Down

Left_Done:

  LDA buttons
  AND #BTN_RIGHT
  BEQ Right_Done

  ;;; MOVE TO THE RIGHT, CHECK FOR WALL
  LDX #$13
  LDA PADDLE, X
  CMP #RIGHT_WALL
  BEQ Right_Done

Right_Down:
  LDA PADDLE, X
  CLC
  ADC #PADDLE_SPEED
  STA PADDLE, X
  DEX
  DEX
  DEX
  DEX
  BPL Right_Down

Right_Done:

Up_Down:
Up_Done:

Down_Down:
Down_Done:
Controls_Done:

  JMP GameEngine_Done

; SPRITE DATA

  .bank 2
  .org $0000
  .incbin "tileset.chr"

  .bank 0
  .org $D000

Nametable:

  .db $37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37
  .db $37,$48,$49,$4A,$4B,$37,$37,$37,$4C,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$58,$59,$5A,$5B,$5C,$37,$37,$37,$37,$5D,$37,$37,$37
  .db $37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37
  .db $37,$64,$47,$46,$45,$57,$44,$56,$55,$54,$44,$45,$47,$57,$46,$55,$56,$46,$44,$55,$47,$45,$54,$56,$57,$57,$56,$45,$46,$44,$65,$37
  .db $37,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$53,$37

  .db $37,$50,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$43,$37
  .db $37,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$62,$37
  .db $37,$70,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$72,$37
  .db $37,$71,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$72,$37
  .db $37,$71,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$73,$37

  .db $37,$50,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$52,$37
  .db $37,$41,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$72,$37
  .db $37,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$63,$37
  .db $37,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$73,$37
  .db $37,$71,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$42,$37

  .db $37,$61,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$63,$37
  .db $37,$51,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$42,$37
  .db $37,$41,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$42,$37
  .db $37,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$43,$37
  .db $37,$50,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$53,$37

  .db $37,$70,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$53,$37
  .db $37,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$43,$37
  .db $37,$51,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$62,$37
  .db $37,$41,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$52,$37
  .db $37,$61,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$52,$37

  .db $37,$51,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$62,$37
  .db $37,$61,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$73,$37
  .db $37,$70,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$63,$37
  .db $37,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$52,$37
  .db $37,$41,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$72,$37

LoadBackground:
  LDA PPU_STATUS ; Reset the PPU latch

  ; Starts at $2000
  LDA #$20
  STA PPU_ADDR
  LDA #$00
  STA PPU_ADDR

  LDA #$00
  STA pointerLo
  LDA #HIGH(Nametable)
  STA pointerHi

  LDY #$00
  LDX #$00
LoadNameTableLoop:
InnerLoop:
  ; LDA #$24
  LDA [pointerLo], y
  STA PPU_DATA
  INY
  CPY #$00
  BNE InnerLoop
  INC pointerHi
  INX
  CPX #$04
  BNE LoadNameTableLoop
  RTS


TitleData:
  ; When an Where ; 13 bytes
  .db $30, $21, $1E, $27, $34, $1A, $27, $34, $30, $21, $1E, $2B, $1E 
  ; Press Start ; 11 bytes
  .db $29, $2B, $1E, $2C, $2C, $34, $2C, $2D, $1A, $2B, $2D

PaletteData:
  .db $0F,$36,$15,$14, $0F,$29,$38,$3C, $0F,$1C,$15,$14, $0F,$02,$38,$3C ; sprite palette data
  .db $22,$29,$1A,$0F, $22,$36,$17,$0F, $22,$30,$21,$0F, $22,$27,$17,$0F ; Background palette data

NumberSprites:
  .db $41 ; 0
  .db $20 ; 1
  .db $21 ; 2
  .db $22 ; 3
  .db $23 ; 4
  .db $30 ; 5
  .db $31 ; 6
  .db $32 ; 7
  .db $33 ; 8
  .db $40 ; 9
  .db $33 ; A
  .db $32 ; B
  .db $31 ; C
  .db $30 ; D
  .db $23 ; E
  .db $22 ; F

SpriteData:
  ; attr:
  ;   01: palette
  ;   5: priority (0: in front of background, 1: behind background)
  ;   6: Flip sprite horizontally
  ;   7: Flip sprite vertically
  
  ; vert tile attr horz

  ; Ball
  .db $A0, $00, $00, $B0
  .db $A0, $00, $40, $B8
  .db $A8, $00, $80, $B0
  .db $A8, $00, $C0, $B8

  ; Paddle
  .db PADDLE_HEIGHT, $01, $00, $70
  .db PADDLE_HEIGHT, $02, $00, $78
  .db PADDLE_HEIGHT, $03, $00, $80
  .db PADDLE_HEIGHT, $02, $40, $88
  .db PADDLE_HEIGHT, $01, $40, $90

  ; Mock time
  .db $08, $41, $01, $30
  .db $08, $41, $01, $38
  .db $08, $41, $01, $48
  .db $08, $41, $01, $50

  ; Score
  .db $08, $41, $01, $C8
  .db $08, $41, $01, $D0
  .db $08, $41, $01, $D8
