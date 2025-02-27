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

// SUBRUTINAS
INCREMENTAR_CONTADOR:
    INC     CONTADOR
    CPI     CONTADOR, 0x10  // Reiniciar si llega a 16
    BRNE    NO_RESET
    LDI     CONTADOR, 0x00

NO_RESET:
    OUT     PORTB, CONTADOR
    RET

DECREMENTAR_CONTADOR:
    CPI     CONTADOR, 0x00  // Verificar si el contador es 0
    BRNE    DECREMENTAR_NORMAL  // Si no es 0, decrementar normalmente
    LDI     CONTADOR, 0x10  // Si es 0, establecer el contador en 16 (0x10)
DECREMENTAR_NORMAL:
    DEC     CONTADOR        // Decrementar el contador
    OUT     PORTB, CONTADOR // Actualizar el puerto B con el nuevo valor
    RET

INICIALIZAR_TIMER:
    LDI     R16, (1 << CS01) | (1 << CS00)
    OUT     TCCR0B, R16  // Prescaler a 64
    LDI     R16, 100
    OUT     TCNT0, R16  // Valor inicial
    RET

ACTUALIZAR_DISPLAY:
    // Mostrar unidades
    SBI     PORTC, 4  // Encender bit 4
    CBI     PORTC, 5  // Apagar bit 5
    LDI     ZH, HIGH(TABLA << 1)
    LDI     ZL, LOW(TABLA << 1)
    ADD     ZL, UNIDADES
    LPM     R23, Z
    OUT     PORTD, R23
    CALL    RETARDO

    // Mostrar decenas
    CBI     PORTC, 4  // Apagar bit 4
    SBI     PORTC, 5  // Encender bit 5
    LDI     ZH, HIGH(TABLA << 1)
    LDI     ZL, LOW(TABLA << 1)
    ADD     ZL, CONTADOR_D
    LPM     R23, Z
    OUT     PORTD, R23
    CALL    RETARDO

    RET

ACTUALIZAR_DECENAS:
    CLR     UNIDADES
    INC     CONTADOR_D
    RET

RETARDO:
    LDI     R18, 0xFF
RETARDO_1:
    DEC     R18
    CPI     R18, 0
    BRNE    RETARDO_1
    LDI     R18, 0xFF
RETARDO_2:
    DEC     R18
    CPI     R18, 0
    BRNE    RETARDO_2
    LDI     R18, 0xFF
RETARDO_3:
    DEC     R18
    CPI     R18, 0
    BRNE    RETARDO_3
    RET

// RUTINAS DE INTERRUPCIÓN
PCINT_ISR:
    IN      R18, PINC  // Leer estado de los pines
    SBRS    R18, 0  // Si PC0 está alto, incrementar
    CALL    INCREMENTAR_CONTADOR
    SBRS    R18, 1  // Si PC1 está alto, decrementar
    CALL    DECREMENTAR_CONTADOR
    RETI

TIMER_ISR:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16

    INC     R22  // Incrementar contador de interrupciones
    CPI     R22, 100  // Comparar con 100
    BRNE    FIN_ISR  // Si no es 100, salir
    CLR     R22  // Reiniciar contador

    INC     UNIDADES  // Incrementar unidades
    CPI     UNIDADES, 10
    BRNE    FIN_ISR  // Si no es 10, salir
    CALL    ACTUALIZAR_DECENAS
    CPI     CONTADOR_D, 6
    BRNE    FIN_ISR
    CLR     CONTADOR_D  // Reiniciar decenas

FIN_ISR:
    CALL    ACTUALIZAR_DISPLAY
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI
