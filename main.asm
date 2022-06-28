;
; Projeto1(Semáforos).asm
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
.def currentStateTime = r20
.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

#define CLOCK 16.0e6
#define delayMs 4.0; 4ms
// Essa função aplica um delay de 4 ms
delay4ms:
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

// Essa função verifica o tempo de transição entre o estado atual e o próximo estado, e coloca o valor no registrador "currentStateTime" 
timeToNextState:
	push r31
	push r30

	// Carregando o valor da memória de programa, contendo o tempo de transição, no "currentStateTime"
	ldi zh, high(initialStateTime*2)// multiplica por 2, para transformar o endereço ea palavra no endereço de byte
	ldi zl, low(initialStateTime*2)
	// Realizamos a adição do endereço "z" com o valor do estado "currentState", para indicar a posição na memória com o valor do tempo de transição correto
	add zl, currentState
	ldi currentStateTime, 0
	adc zh, currentStateTime

	lpm currentStateTime, z

	pop r30
	pop r31

	ret

// Essa função atualiza as cores dos registradores de cada semáforo(s1, s2, s3, s4 e pedestre)
trafficLightColorUpdate:
	push r31
	push r30
	push r16
	push r0
	push r1

	// s1, s2, s3, s4 e pedestre recebem o valor referente à cor do semáforo do estado atual(carregando da memória de programa)
	ldi zh, high(initialStateColor*2)// multiplica por 2, para transformar o endereço de palavra no endereço de byte
	ldi zl, low(initialStateColor*2)
	// fazendo uma adição do endereço "z" com o valor do estado "currentState"*5, que vai indicar a posição na memória com o valor das cores de cada semáforo
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

	pop r1
	pop r0
	pop r16
	pop r30
	pop r31

	ret

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16
	
	inc count

	rcall timeToNextState ; chamada da função que registra o tempo necessário para ir ao próximo estado em "currentStateTime"

	// caso count == currentStateTime, então os semáforos vão para o próximo estado
	cp count, currentStateTime
	brne ifExit1

		ldi count, 0

		// Caso currentState == 6 e count == currentStateTime, então quer dizer que os semáforos vão para o primeiro estado novamente, então definimos currentState = 0
		cpi currentState, 6
		brne else
			ldi currentState, 0
			rjmp endIf
		else:
			inc currentState
		endIf:

		rcall trafficLightColorUpdate ; chamada da função que atualiza as cores dos semáforos nos registradores "s1", "s2", "s3", "s4" e "pedestre", a partir do "currentState"
		
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

	;Output do semáforo que vai ser transmitido pelos pinos 
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
	sbr r16, 1 <<OCIE1A //Sets specified bits in register Rd(no caso apenas define 1 na posição OCIE1A)
	sts TIMSK1, r16

	// Estado inicial
	ldi currentState, 0
	ldi count, 0
	rcall trafficLightColorUpdate ; chamada da função que atualiza as cores dos semáforos nos registradores "s1", "s2", "s3", "s4" e "pedestre", a partir do "currentState"

	sei // essa instrução ativa a flag global de interrupção
	main_lp:
		/* Usando as informações atualizadas dos semáforos, obtidas na interrupção, para inserir nos pinos corretos do arduino( 
		porta B => (11)->base do transistor de cada display(7-segmentos) (1111)->count, 
		porta D => (11111)->base do transistor de cada semáforo(controle)) (111)->semáforo
		*/

		// Adiquirindo os valores do 1º display de 7-segmentos(dezenas)

		rcall timeToNextState ; chamada da função que registra o tempo necessário para ir ao próximo estado em "currentStateTime"
		sub currentStateTime, count ; adiquirindo o tempo restante para o próximo estado

		//fazendo um while para adiquirir os valores das dezenas e unidades("output, currentStateTime", respectivamente)
		ldi output, 0
		rjmp loopTest
		loop:
			subi currentStateTime, 10 ; temp possui o valor de count no início e no final vai ficar com as unidades apenas
			inc output ; incrementando o valor corespondente as dezenas
		loopTest:
			cpi currentStateTime, 10
			brge loop ; while(currentStateTime >= 10) {executo o "loop"}

		ori output, 0b10 << 4 ; Acendendo o display das dezenas(ativa HIGH apenas na base do transistor do display das dezenas)
		out PORTB, output
		rcall delay4ms

		// Adiquirindo os valores do 2º display de 7-segmentos(unidades)
		mov output, currentStateTime ; inserindo os valores das unidades
		ori output, 0b01 << 4 ; Acendendo o display das unidades(ativa HIGH apenas na base do transistor do display das unidades)
		out PORTB, output
		
		//Acendendo o semáforo 1
		mov output, s1
		ori output, 0b00001 << 3 ; aplicando um "ou" lógico com o valor do "controlador" desse semáforo
		/* 
		Exemplo: s1 = 010, então "ori output, 0b00001 << 3" indica que 
		output = 00001010, em que (00001)-> valor da base do transistor que vai fechar o circuito do semáforo s1 (010)-> cor do semáforo
		*/
		out PORTD, output
		rcall delay4ms

		//Acendendo o semáforo 2
		mov output, s2
		ori output, 0b00010 << 3
		out PORTD, output
		rcall delay4ms

		//Acendendo o semáforo 3
		mov output, s3
		ori output, 0b00100 << 3
		out PORTD, output
		rcall delay4ms

		//Acendendo o semáforo 4
		mov output, s4
		ori output, 0b01000 << 3
		out PORTD, output
		rcall delay4ms

		//Acendendo o semáforo de pedestre
		mov output, pedestre
		ori output, 0b10000 << 3
		out PORTD, output

		rjmp main_lp

.cseg
initialStateTime: // tempos de transição para cada estado
	// Guardando valores de tempo de transição entre estados na program memory(.cseg)
	.db 20, 4, 53, 4, 20, 4, 17, $FF // coloquei $FF no último para quando fazer a leitura, poder pular uma palavra
initialStateColor:
	// Guardando cores de cada semáforo em cada estado(verde = 0b1, amarelo = 0b10, vermelho = 0b100)
	// 1º estado(S1: Vermelho, S2: Verde, S3: Verde, S4: Vermelho, pedestre: Vermelho), ..., 7º estado
	.db 0b100, 1, 1, 0b100, 0b100,   0b100, 1, 2, 0b100, 0b100,   0b100, 1, 0b100, 1, 0b100,   0b100, 2, 0b100, 2, 0b100,   1, 0b100, 0b100, 0b100, 0b100,   2, 0b100, 0b100, 0b100, 0b100,   0b100, 0b100, 0b100, 0b100, 1,   $FF
