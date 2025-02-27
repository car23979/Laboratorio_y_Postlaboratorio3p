/*
PostLaboratorio3.asm

Autor: David Carranza
Proyecto: Laboratorio3 y Postlaboratorio3

Creado: 21/02/2025 

Descripción:
*/

// Encabezado
.include "M328PDEF.inc"

// Definición de registros
.DEF    DISPLAY = R21
.DEF    DECENAS = R23
.DEF    UNIDADES = R24
.DEF    CONTADOR_D = R25

// Variables
.ORG    0x0000
    RJMP    INICIO  // Vector Reset

.ORG    PCI1addr
    RJMP    PCINT_ISR  // Vector de interrupción PCINT1
.ORG    0x0020
    RJMP    TIMER_ISR

.cseg
.def CONTADOR = R19  // Variable para el contador

// Configuración de Pila
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16
		
// Configuración MCU
INICIO:
	// Configurar Prescaler
    LDI     R16, (1 << CLKPCE)
    STS     CLKPR, R16  // Habilitar cambio de PRESCALER
    LDI     R16, 0b00000100
    STS     CLKPR, R16  // Prescaler a 16 (F_cpu = 1MHz)
		
	// Inicializar Timer0
    CALL    INICIALIZAR_TIMER

	// Configurar PORTB y PORTD como salidas
	LDI		R16, 0xFF
	OUT		DDRD, R16	//TODO PORTD COMO SALIDA
	OUT		DDRB, R16	//TODO PORTB COMO SALIDA
	LDI		R16, 0x00
	OUT		PORTD,	R16	//TODO PORTD PULL UP DESACTIVADO
	OUT		PORTB, R16  //TODO PORTD PULL UP DESACTIVADO
	 
	// Configurar PORTC como entrada con pull-up
	LDI		R16, 0x20
	OUT		DDRC, R16	
	LDI		R16, 0x1F
	OUT		PORTC, R16	

	// Deshabilitar serial (apaga LEDs adicionales)
    LDI     R16, 0x00
    STS     UCSR0B, R16

	// Iniciar el display en 0s
    LDI     DISPLAY, 0x00
    CALL    ACTUALIZAR_DISPLAY
    LDI     CONTADOR_D, 0x00

	// Configurar interrupciones
    LDI     R16, (1 << PCIE1)  // Habilitar PCIE1
    STS     PCICR, R16
    LDI     R16, (1 << PCINT8) | (1 << PCINT9)  // Habilitar PC0 y PC1
    STS     PCMSK1, R16

    LDI     R16, (1 << TOIE0)  // Habilitar interrupción Timer0
    STS     TIMSK0, R16

    SEI  // Habilitar interrupciones globales

    LDI     R17, 0x00  // Inicializar contador


MAIN:
	RJMP	MAIN

//TIMER0 COMO INTERRUPCION
INIT_TMR0:

	LDI		R16, (1<<CS01) | (1<<CS00) //PRESCALER 64
	OUT		TCCR0B, R16				   //ACTIVA EL PRESCALER EN TCCR0B
	LDI		R16, 60				   //VALOR DESDE DONDE INICIAMOS
	OUT		TCNT0, R16				   //CARGA EL VALOR A TCNT0 
	//HABILITAR INTERRUPCION DE OVERFLOW
	LDI		R16, (1 << TOIE0)			//INTERRUPCION POR OVERFLOW
	STS		TIMSK0, R16					//HABILITAR MASCARA

	RET
//PORTC COMO INTERRUPCION
PORTC_INT:
	
	LDI			R16, (1 << PCIE1)					//HABLITANDO PIN CHANGE EN PORTC
	STS			PCICR, R16
		
	LDI			R16, (1 << PCINT8) | (1 << PCINT9)	//HABILITAR PIN CHANGE PC0 & PC1
	STS			PCMSK1, R16

	RET


DISPLAY_CHANGE:

	PUSH    R16
    IN      R16, SREG
    PUSH    R16
	PUSH	R17
	LDI		R16, 100			// VALOR QUE SE CARGA AL TEMPORIZADOR PARA CONTAR
	OUT		TCNT0, R16
	
	INC		COUNTER				
	CPI		COUNTER, 100		//HACE LA COMPARACIÓN SI ES IGUAL A 10(QUE TAN RAPIDO CUENTA)
	BRNE	CONTADOR_EXIT		//Z = 0, SALTA A CONTADOR_EXIT. Z = 1, NO SALTA.
	CLR		COUNTER		

    ; Verificar si se debe incrementar o decrementar el contador
	
	INC		DISP_COUNTER
	ANDI	DISP_COUNTER,  0x0F
    LDI		ZH, HIGH(DATA << 1)
	LDI		ZL, LOW(DATA << 1)	//PUNTERO APUNTA A LA TABLA Z
	ADD		ZL, DISP_COUNTER				//Añadir el valor del contador R20 al puntero Z para obtener la salida en PORTD
	LPM		R16, Z				//Copia el valor guardado en el nuevo Z
	OUT		PORTD, R16			//Modifico el 7 segmentos en PORTD
CONTADOR_EXIT: 
	
	POP		R17
    POP     R16
    OUT     SREG, R16
    POP     R16   
	RETI	


//PINCHANGE COMO INTERRUPCION
PIN_CHANGE:
	
	PUSH    R16
    IN      R16, SREG
    PUSH    R16
	PUSH	R17

    IN      R16, PINC		//LEER PINC
	MOV		R17, R16
	EOR		R17, PIN_PREV	//LEE LOS CAMBIOS
	BREQ	EXIT  
	CALL	DELAY

	IN      R16, PINC		//LEER PINC
	MOV		R17, R16
	EOR		R17, PIN_PREV	//LEE LOS CAMBIOS
	BREQ	EXIT  
    
	SBRC	R17, PC1
	CALL	INCREMENTO

	SBRC	R17, PC0
	CALL	DECREMENTO

	MOV		PIN_PREV, R16	//ACTUALIZAR CON EL ESTADO EN QUE SE QUEDO

EXIT:
	POP		R17
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI
	

	
DELAY:
    LDI     R19, 0xFF
SUB_DELAY1:
    DEC     R19
    CPI     R19, 0
    BRNE    SUB_DELAY1
    LDI     R19, 0xFF
SUB_DELAY2:
    DEC     R19
    CPI     R19, 0
    BRNE    SUB_DELAY2
    LDI     R19, 0xFF
SUB_DELAY3:
    DEC     R19
    CPI     R19, 0
    BRNE    SUB_DELAY3
    RET
