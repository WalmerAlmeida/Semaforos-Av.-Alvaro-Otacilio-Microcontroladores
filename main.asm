;
; Projeto1(Sem�foros).asm
;
; Created: 08/06/2022 11:47:12
; Author : walmer
;

.def productLow = r0
.def productHigh = r1
.def s1 = r3
.def s2 = r4
.def s3 = r5
.def s4 = r6
.def pedestre = r7
.def temp = r16
.def currentState = r17 ;estado atual
.def count = r18
.def output = r19
.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

#define CLOCK 16.0e6
#define delayMs 4.0; 4ms
delay5ms:
	push r22
	push r21
	push r20

	ldi r22, byte3(CLOCK * delayMs / (5 * 1000))
	ldi r21, high(CLOCK * delayMs / (5 * 1000))
	ldi r20, low(CLOCK * delayMs / (5 * 1000))

	subi r20, 1
	sbci r21, 0
	sbci r22, 0
	brcc pc-3

	pop r20
	pop r21
	pop r22

	ret

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16
	
	inc count

	// temp recebe o tempo da transi��o do estado atual para o pr�ximo(carregando da mem�ria de programa)
	ldi zh, high(initialStateTime*2)// multiplica por 2, para transformar o endere�o ea palavra no endere�o de byte
	ldi zl, low(initialStateTime*2)
	// fazendo uma adi��o do endere�o "z" com o valor do estado "currentState", que vai indicar a posi��o na mem�ria com o valor do tempo de transi��o correto
	add zl, currentState
	ldi temp, 0
	adc zh, temp

	lpm temp, z

	// caso count == temp, ent�o os sem�foros v�o para o pr�ximo estado
	cp count, temp
	brne ifExit1

		ldi count, 0

		// Caso currentState == 6 e count == temp, quer dizer que os sem�foros v�o para o primeiro estado novamente, ent�o definimos currentState = 0
		cpi currentState, 6
		brne else
			ldi currentState, 0
			rjmp endIf
		else:
			inc currentState
		endIf:

		// s1, s2, s3, s4 e pedestre recebem o valor referente � cor do sem�foro do estado atual(carregando da mem�ria de programa)
		ldi zh, high(initialStateColor*2)// multiplica por 2, para transformar o endere�o de palavra no endere�o de byte
		ldi zl, low(initialStateColor*2)
		// fazendo uma adi��o do endere�o "z" com o valor do estado "currentState"*5, que vai indicar a posi��o na mem�ria com o valor das cores de cada sem�foro
		ldi temp, 5
		mul currentState, temp //multiplica e insere nos registradores r1(productHigh) e r0(productLow)
		add zl, productLow
		ldi temp, 0
		adc zh, temp

		lpm s1, z
		adiw z, 1
		lpm s2, z
		adiw z, 1
		lpm s3, z
		adiw z, 1
		lpm s4, z
		adiw z, 1
		lpm pedestre, z
		
	ifExit1:
	
	pop r16
	out SREG, r16
	pop r16
	reti


reset:
	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	;Output do sem�foro que vai ser transmitido pelos pinos 
	ldi temp, $FF
	out DDRB, temp
	out DDRD, temp
	ldi output, 0
	out PORTB, output
	out PORTD, output

	#define CLOCK 16.0e6 ;clock speed  //obs.: isso corresponde ao clock que o microcontrolador vai funcionar
	#define DELAY 1.0;seconds
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif
	
	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b0001000 | 0b100 = 0b0001100
	sts TCCR1B, temp ;start counter

	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A //Sets specified bits in register Rd(no caso apenas define 1 na posi��o OCIE1A)
	sts TIMSK1, r16

	// Estado inicial, obs.: iniciamos no �ltimo estado faltando 1 segundo para ir para o estado 0.
	ldi currentState, 6
	ldi count, 16

	sei
	main_lp:
		/* Usando as informa��es atualizadas dos sem�foros, obtidas na interrup��o, para inserir nos pinos corretos do arduino( porta B() => (11)->base do transistor de cada display(7-segmentos) (1111)->count, 
		porta D => (111)->sem�foro (11111)->base do transistor de cada sem�foro(controle))
		*/
		//inc output
		//ldi output, (count&0b1111 |
		//out PORTB

		
		//Acendendo o sem�foro 1
		mov output, s1
		ori output, 0b00001 << 3
		out PORTD, output
		rcall delay5ms

		//Acendendo o sem�foro 2
		mov output, s2
		ori output, 0b00010 << 3
		out PORTD, output
		rcall delay5ms

		//Acendendo o sem�foro 3
		mov output, s3
		ori output, 0b00100 << 3
		out PORTD, output
		rcall delay5ms

		//Acendendo o sem�foro 4
		mov output, s4
		ori output, 0b01000 << 3
		out PORTD, output
		rcall delay5ms

		//Acendendo o sem�foro de pedestre
		mov output, pedestre
		ori output, 0b10000 << 3
		out PORTD, output
		rcall delay5ms

		rjmp main_lp

.cseg
initialStateTime: // tempos de transi��o para cada estado
	// Guardando valores de tempo de transi��o entre estados na program memory(.cseg)
	.db 20, 4, 53, 4, 20, 4, 17, $FF // coloquei $FF no �ltimo para quando fazer a leitura, poder pular uma palavra
initialStateColor:
	// Guardando cores de cada sem�foro em cada estado(verde = 0b1, amarelo = 0b10, vermelho = 0b100)
	// 1� estado(S1: Vermelho, S2: Verde, S3: Verde, S4: Vermelho, pedestre: Vermelho), ..., 7� estado
	.db 0b100, 1, 1, 0b100, 0b100,   0b100, 1, 2, 0b100, 0b100,   0b100, 1, 0b100, 1, 0b100,   0b100, 2, 0b100, 2, 0b100,   1, 0b100, 0b100, 0b100, 0b100,   2, 0b100, 0b100, 0b100, 0b100,   0b100, 0b100, 0b100, 0b100, 1,   $FF
