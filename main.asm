;
; Projeto1(Semáforos).asm
;
; Created: 08/06/2022 11:47:12
; Author : walmer
;

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Associando os registradores às variáveis que serão utilizadas no programa


//Registradores que salvam os valores de operações de produtos 

.def productLow = r0
.def productHigh = r1


//Conectores dos Sinais

.def sinal_1 = r3 ;(Branco)
.def sinal_2 = r4 ;(Branco)
.def sinal_3 = r5 ;(Branco)
.def sinal_4 = r6 ;(Branco)
.def pedestre = r7 ;(Cinza)


.def temp = r16
.def currentState = r17
.def count = r18 
.def output = r19
.def currentStateTime = r20

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

//->>> Start Point

.cseg ; diz qual memória vai ser utilizada no programa
jmp reset ; flag que indica onde o programa vai iniciar
.org OC1Aaddr ; guarda a interrupção (OCI1A_Interrupt) nesse lugar da memória
jmp OCI1A_Interrupt ; a interrupção é caso o delay passe de 1s, para o programa não ficar em loop infinito

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

#define CLOCK 16.0e6 ; corresponde à frenquência que o arduino UNO funciona
#define delayMs 4.0  ; (s) serve para que a gente enxergue o led aceso a olho nú

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Essa função aplica um delay de 4 ms

delay4ms:

	;-------
	push r22
	push r21
	push r20
	;-------


	// Calculando a quantidade  de ciclos de acordo com o valor do delay

	ldi r22, byte3(CLOCK * delayMs / (5 * 1000)) ; terceiro byte mais significativo
	ldi r21, high(CLOCK * delayMs / (5 * 1000))
	ldi r20, low(CLOCK * delayMs / (5 * 1000))


	subi r20, 1  
	sbci r21, 0  
	sbci r22, 0 
	brcc pc-3	 

	;-------
	pop r20
	pop r21
	pop r22
	;-------

	ret

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Essa função verifica o tempo de transição entre o estado atual e o próximo estado, e coloca o valor no registrador "currentStateTime" 

timeToNextState:

	;-------
	push r31
	push r30
	;-------

	
	// Carregando o valor da memória de programa, contendo o tempo de transição, no "currentStateTime"
	
	ldi zh, high(initialStateTime*2)  ; multiplica por 2, para transformar o endereço em palavra no endereço de byte
	ldi zl, low(initialStateTime*2)
	
	
	// Realizamos a adição do endereço "z" com o valor do estado "currentState", para indicar a posição na memória com o valor do tempo de transição correto
	
	add zl, currentState
	ldi currentStateTime, 0
	adc zh, currentStateTime

	
	lpm currentStateTime, z

	;-------
	pop r30
	pop r31
	;-------

	ret

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Essa função atualiza as cores dos registradores de cada semáforo(sinal_1, sinal_2, sinal_3, sinal_4 e pedestre) 

trafficLightColorUpdate:

	;-------
	push r31
	push r30

	push r16

	push r0
	push r1
	;-------


	// sinal_1, sinal_2, sinal_3, sinal_4 e pedestre recebem o valor referente à cor do semáforo do estado atual(carregando da memória de programa)
	
	ldi zh, high(initialStateColor*2) ; multiplica por 2, para transformar o endereço de palavra no endereço de byte
	ldi zl, low(initialStateColor*2)
	
	
	// fazendo uma adição do endereço "z" com o valor do estado "currentState"*5, que vai indicar a posição na memória com o valor das cores de cada semáforo
	
	ldi temp, 5
	mul currentState, temp ; multiplica e insere nos registradores r1(productHigh) e r0(productLow)
	add zl, productLow
	ldi temp, 0
	adc zh, temp


	lpm sinal_1, z
	adiw z, 1

	lpm sinal_2, z
	adiw z, 1

	lpm sinal_3, z
	adiw z, 1

	lpm sinal_4, z
	adiw z, 1

	lpm pedestre, z

	;-------
	pop r1
	pop r0

	pop r16

	pop r30
	pop r31
	;-------

	ret

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

OCI1A_Interrupt:

	;-----------
	push r16
	in r16, SREG
	push r16
	;-----------
	
	inc count

	rcall timeToNextState ; chamada da função que registra o tempo necessário para ir ao próximo estado em "currentStateTime"

	;-----------------------------------------------------------------------------

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

		rcall trafficLightColorUpdate ; chamada da função que atualiza as cores dos semáforos nos registradores "sinal_1", "sinal_2", "sinal_3", "sinal_4" e "pedestre", a partir do "currentState"
		
	ifExit1:
	
	;-----------------------------------------------------------------------------
	
	;-----------
	pop r16
	out SREG, r16
	pop r16
	;-----------

	reti

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

reset:
	
	;--------------------
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	;--------------------

	//Output do semáforo que vai ser transmitido pelos pinos 
	
		; seta os pinos como pinos são de saida
	ldi temp, $FF
	out DDRB, temp 
	out DDRD, temp
		
		; botando 0 em todos os pinos
	ldi output, 0
	out PORTB, output
	out PORTD, output
	
	;--------------------------------------------------------------------------------------------------------------------------

	#define CLOCK 16.0e6 ; corresponde ao clock que o microcontrolador vai funcionar
	#define DELAY 1.0 	 ; (s) marca quando ocorre uma interrupção, onde vai ser iniciado o tratamento
	
	;--------------------------------------------------------------------------------------------------------------------------

	//qual a diferença dessas duas
	.equ PRESCALE = 0b100 ; 256 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ; Waveform generation mode: CTC (?)
	
	
	//porque essa formula
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY)) 
	.if TOP > 65535 ; you must ensure this value is between 0 and 65535 (proque o registrador do timer só consegue armazenar até esse tamanho)
	.error "TOP is out of range"
	.endif
	
	
	// On MEGA series, write high byte of 16-bit timer registers first

	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	

	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	
	sts TCCR1A, temp
	
	;upper 2 bits of WGM and clock select
	
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CSinal_10)
	
			; WGM >> 2 = 0b0100 >> 2 = 0b0001
			; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
			; (PRESCALE << CSinal_10) = 0b100 << 0 = 0b100
			; 0b0001000 | 0b100 = 0b0001100
	
	sts TCCR1B, temp ;start counter

	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A ; Sets specified bits in register Rd (no caso apenas define 1 na posição OCIE1A)
	sts TIMSK1, r16

	ldi currentState, 0
	ldi count, 0
	
	//rjump em uma quantidadde de espaços n mto grande, jump tem dois ciclos eh pra quando repcias de mairo

	
	//chamada da função que atualiza as cores dos semáforos nos registradores "sinal_1", "sinal_2", "sinal_3", "sinal_4" e "pedestre", a partir do "currentState"

	rcall trafficLightColorUpdate 

	
	sei ; ativa a flag de interrupção global, que permite que uma interrupção seja tratada

	;--------------------------------------------------------------------------------------------------------------------------

	main_loop:
	
		/* Usando as informações atualizadas dos semáforos, obtidas na interrupção, para inserir nos pinos corretos do arduino:
			porta B => (11)-> base do transistor de cada display(7-segmentos) (1111)->count, 
			porta D => (11111)-> base do transistor de cada semáforo(controle)) (111)->semáforo
		*/


		// Adiquirindo os valores do 1º display de 7-segmentos(dezenas)

		rcall timeToNextState ; chamada da função que registra o tempo necessário para ir ao próximo estado em "currentStateTime"
		sub currentStateTime, count ; adiquirindo o tempo restante para o próximo estado


		//fazendo um while para adiquirir os valores das dezenas e unidades(output, currentStateTime)

		ldi output, 0
		rjmp loopTest

		;-----------------------------------------------------------------------------------------------------------------
		
		loop:

			subi currentStateTime, 10 ; temp possui o valor de count no início e no final vai ficar apenas com as unidades 
			inc output ; incrementando o valor corespondente as dezenas
		
		;-----------------------------------------------------------------------------------------------------------------

		loopTest:

			cpi currentStateTime, 10
			brge loop

		;-----------------------------------------------------------------------------------------------------------------

		ori output, 0b10 << 4 ; Acendendo o display das dezenas(ativa HIGH apenas na base do transistor do display das dezenas)
		out PORTB, output
		rcall delay4ms

		// Adiquirindo os valores do 2º display de 7-segmentos(unidades)

		mov output, currentStateTime ; inserindo os valores das unidades
		ori output, 0b01 << 4 ; Acendendo o display das unidades(ativa HIGH apenas na base do transistor do display das unidades)
		out PORTB, output

		;-------------------------
		
			//Acendendo o semáforo 1

		mov output, sinal_1
		ori output, 0b00001 << 3
		out PORTD, output
		rcall delay4ms

		;-------------------------

		/	/Acendendo o semáforo 2

		mov output, sinal_2
		ori output, 0b00010 << 3
		out PORTD, output
		rcall delay4ms

		;--------------------------
		
			//Acendendo o semáforo 3

		mov output, sinal_3
		ori output, 0b00100 << 3
		out PORTD, output
		rcall delay4ms

		;--------------------------

			//Acendendo o semáforo 4

		mov output, sinal_4
		ori output, 0b01000 << 3
		out PORTD, output
		rcall delay4ms

		;---------------------------

			//Acendendo o semáforo de pedestre

		mov output, pedestre
		ori output, 0b10000 << 3
		out PORTD, output

		rjmp main_loop

	;--------------------------------------------------------------------------------------------------------------------------

.cseg

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Essa função define os tempos de transição e as cores de cada semáforo para cada estado

initialStateTime: 
	
		// Guardando valores de tempo de transição entre estados na program memory(.cseg)
		// coloquei $FF no último para quando fazer a leitura, poder pular uma palavra initialStateColor:
	
	.db 20, 4, 53, 4, 20, 4, 17, $FF 
	
		// Guardando cores de cada semáforo em cada estado(verde = 0b1, amarelo = 0b10, vermelho = 0b100)
		// Ex: 1º estado(Sinal_1: Vermelho, Sinal_2: Verde, Sinal_3: Verde, Sinal_4: Vermelho, pedestre: Vermelho), ..., 7º estado.
	
	.db 0b100, 1, 1, 0b100, 0b100,   0b100, 1, 2, 0b100, 0b100,   0b100, 1, 0b100, 1, 0b100,   0b100, 2, 0b100, 2, 0b100,   1, 0b100, 0b100, 0b100, 0b100,(tira essa virgula)
	
;---------------------------------------------------------------------------------------------------------------------------------------------------------------------


//RASCUNHO

;Transmit byte - blocks until transmit buffer can accept a byte
;The param, byte to transmit, is in r24
.def byte_tx = r24
transmit:
	lds r17, ucsr0a
	sbrs r17, udre0		;wait for tx buffer to be emptyrjmp transmit ;not ready yet
	rjmp transmit
	sts udr0, byte_tx	;transmit character
	ret
.undef byte_tx
