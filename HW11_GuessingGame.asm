; uses basic macro definitions from tbird.asm, Steven L. Garverick

; Cycles output bits RB2-0 according to the right-hand tbird tail lights
; Cycles output bits RB5-3 according to the left-hand tbird tail lights
; Reads Haz input from RA2
; Reads Left input from RA1
; Reads Right input from RA0

; There is a delay of approximately 0.5 seconds from one state to the next
; This delay is created using a 16*256 double loop
; The loop delay is approx 16 * 256 * 3 CPU cycles 
; Using an oscillator frequeny of 100 kHz, a CPU cycle is 40 usec
; Therefore, the loop delay is about 492 msec 
 
; CPU configuration
; (16F84 with RC osc, watchdog timer off, power-up timer on)

	processor 16f84A
	include <p16F84A.inc>
	__config _RC_OSC & _WDT_OFF & _PWRTE_ON

; some handy macro definitions

IFSET macro fr,bit,label
	btfss fr,bit ; if (fr.bit) then execute code following macro
	goto label ; else goto label	
      endm

IFCLR macro fr,bit,label
	btfsc fr,bit ; if (! fr.bit) then execute code following macro
	goto label ; else goto label
	  endm

IFEQ macro fr,lit,label
	movlw lit
	xorwf fr,W
	btfss STATUS,Z ; (fr == lit) then execute code following macro
	goto label ; else goto label
	 endm

IFNEQ macro fr,lit,label
	movlw lit
	xorwf fr,W
	btfsc STATUS,Z ; (fr != lit) then execute code following macro
	goto label ; else goto label
	 endm

MOVLF macro lit,fr
	movlw lit
	movwf fr
	  endm

MOVFF macro from,to
	movf from,W
	movwf to
  	  endm

; file register variables

nextS equ 0x0C 	; next state (output)
octr equ 0x0D	; outer-loop counter for delays
ictr equ 0x0E	; inner-loop counter for delays

; state definitions for Port B

S1 equ B'00000001' ; S1
S2 equ B'00000010' ; S2
S3 equ B'00000100' ; S3
S4 equ B'00001000' ; S4
SERR equ B'00010000' ; SERR
SOK equ B'00100000' ; SOK

; input bits on Port A
G1 equ 0
G2 equ 1
G3 equ 2
G4 equ 3

; beginning of program code

	org 0x00	; reset at address 0
reset:	goto	init	; skip reserved program addresses	

	org	0x08 	; beginning of user code
init:	
; set up RB5-0 as outputs, RA3-0 are already inputs
	bsf	STATUS,RP0	; switch to bank 1 memory (not necessary in PIC18)
	MOVLF B'11000000',TRISB	; RB7-6 are inputs, RB5-0 are outputs 
	MOVLF B'11111111',TRISA
	bcf	STATUS,RP0	; return to bank 0 memory (not necessary in PIC18)

; initialize state variables
	MOVLF	S1,nextS ; nextS = ID 

mloop:	; here begins the main program loop
	MOVFF	nextS,PORTB ; PORTB = nextS, i.e. PORTB is the current state

	goto delay
	
pos_A:
; check if Guess is correct
	IFSET	PORTA, G1, noG1;  if (Guess = 0001)
	IFCLR   PORTA, G2, noG1   
	IFCLR   PORTA, G3, noG1
	IFCLR   PORTA, G4, noG1

GG1:
    IFEQ	PORTB, S1, N2 ;        if (state = S1)
    MOVLF	SOK, nextS ;               nextS = SOK;	
	goto	N2

noG1:   
        IFSET	PORTA, G2, noG2 ;   else if (Guess = 0010) 
	IFCLR	PORTA, G1, noG2   
	IFCLR   PORTA, G3, noG2
	IFCLR   PORTA, G4, noG2
	
	IFEQ	PORTB, S2, N2 ;          if (state == S2)
	MOVLF	SOK, nextS ;                 nextS = SOK;
	goto N2
noG2:
    IFSET	PORTB, G3, noG3 ;          else if (Guess = 0100)
    IFCLR       PORTB, G1, noG3 
    IFCLR       PORTB, G2, noG3
    IFCLR       PORTB, G4, noG3
    
    IFEQ	PORTB, S3, N2 ;          if (state == S3)
	MOVLF	SOK, nextS ;                 nextS = SOK;
	goto N2
noG3:
    IFSET	PORTB, G4, N2 ;         else if (Guess = 1000)
    IFCLR       PORTB, G1, N2 
    IFCLR       PORTB, G2, N2
    IFCLR       PORTB, G3, N2
    
    IFEQ	PORTB, S4, N2 ;          if (Guess = S4)
	MOVLF	SOK, nextS ;                 nextS = SOK
	goto N2


N2:
    IFEQ	PORTB, S1, N3
    IFEQ	PORTA, 0x00, CSERR1
	MOVLF S2, nextS
	goto mloop
CSERR1:
    IFSET	PORTA, G2, A1
    goto F1
    A1:
    IFSET	PORTA, G3, B1
    goto F1
    B1:
    IFSET	PORTA, G4, N3
    goto F1
    
    F1:
    MOVLF SERR, nextS
    goto mloop
    
N3:
    IFEQ	PORTB, S2, N4
    IFEQ	PORTA, 0x00, CSERR2
	MOVLF S3, nextS
	goto mloop
CSERR2:
    IFSET	PORTA, G1, A2
    goto F2
    A2:
    IFSET	PORTA, G3, B2
    goto F2
    B2:
    IFSET	PORTA, G4, N4
    goto F2

    F2:
    MOVLF SERR, nextS
    goto mloop
    
N4:
    IFEQ	PORTB, S3, N1
    IFEQ	PORTA, 0x00, CSERR3
	MOVLF S4, nextS
	goto mloop
CSERR3:
    IFSET	PORTA, G1, A3
    goto F3
    A3:
    IFSET	PORTA, G2, B3
    goto F3
    B3:
    IFSET	PORTA, G4, N1
    goto F3
    
    F3:
    MOVLF SERR, nextS
    goto mloop
    
N1:
    IFEQ	PORTB, S4, AT_SERR
    IFEQ	PORTA, 0x00, CSERR4
	MOVLF S1, nextS
	goto mloop
CSERR4:
    IFSET	PORTA, G1, A4
    goto F4
    A4:
    IFSET	PORTA, G2, B4
    goto F4
    B4:
    IFSET	PORTA, G3, N3
    goto F4
    
    F4:
    MOVLF SERR, nextS
    goto mloop
   
AT_SERR:
    IFEQ	PORTB, SERR, AT_OK
    IFSET	PORTA, G1, A5
    goto F5
    A5:
    IFSET	PORTA, G2, B5
    goto F5
    B5:
    IFSET	PORTA, G3, C5
    goto F5
    C5:
    IFSET	PORTA, G4, NSET
    goto F5
    
    F5:
    MOVLF SERR, nextS
    goto mloop

NSET:
    MOVLF S1, nextS
    goto mloop

AT_OK:
    IFSET	PORTA, G1, A6
    goto F6
    A6:
    IFSET	PORTA, G2, B6
    goto F6
    B6:
    IFSET	PORTA, G3, C6
    goto F6
    C6:
    IFSET	PORTA, G4, NSET
    goto F6
    F6:
    MOVLF SOK, nextS

		
delay: ; create a delay of about 1 seconds
    ; consider 25 KHz freq, then each T = 1/ (25 * 10^3)
    ;therefore T = 4*10^-5
    ;since each instruction executes at 4T we know each one takes 4 * 4 * 10^-5 time
    ;therefore 1s / (4 * 4 * 10^-5) = 6250
    ;therefore we execute 6250 lines
    ;6250/256 = 24.4
    ;we round to 24
    ;therefore octr must = 24
    ;because 24 * 256 * (4 * 4 * 10^-5) approximately = 1 second delay
    
	MOVLF	d'24',octr ; initialize outer loop counter to 24
d1:	clrf	ictr	; initialize inner loop counter to 256
d2: 
	decfsz	ictr,F	; if (--ictr != 0) loop to d2
	goto 	d2		 	
	decfsz	octr,F	; if (--octr != 0) loop to d1 
	goto	d1 

endloop: ; end of main loop
    
	goto	pos_A

	end		; end of program code		
