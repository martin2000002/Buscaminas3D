.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib

include include\constants.inc
include include\structures.inc
include src\game\game.inc

; Variables externas definidas en main.asm
EXTERN gameState:GameState

.data
; Colores para las celdas
CELL_COLOR_NORMAL    EQU 00D3D3D3h   ; Color normal (gris claro)
CELL_COLOR_CLICKED   EQU 0000FF00h   ; Color cuando se hace clic (verde)
CELL_COLOR_FLAGGED   EQU 000000FFh   ; Color cuando tiene bandera (rojo)
CELL_COLOR_MINE      EQU 00000000h   ; Color para las minas (negro)

; Variables para generación aleatoria
seed DWORD 12345       ; Semilla para generación de números aleatorios

.data?
cellStates BYTE 6 * 4 * 4 * 4 dup(?)  ; Estado de cada celda (hasMine, isRevealed, isFlagged, adjacentMines)

.code

;-----------------------------------------------------------------------------
; Random - Genera un número pseudoaleatorio
; Retorna:
;   eax - Número aleatorio generado
;-----------------------------------------------------------------------------
Random proc
    ; Algoritmo simple de congruencia lineal
    mov eax, seed
    imul eax, 1103515245
    add eax, 12345
    mov seed, eax
    
    ; Devolver un número entre 0 y 32767
    shr eax, 16
    and eax, 7FFFh
    
    ret
Random endp

;-----------------------------------------------------------------------------
; InitGame - Inicializa el estado del juego
;-----------------------------------------------------------------------------
InitGame proc
    LOCAL i:DWORD
    LOCAL j:DWORD
    LOCAL k:DWORD
    LOCAL cellOffset:DWORD
    LOCAL minesLeft:DWORD
    LOCAL gridIndex:DWORD
    LOCAL cellX:DWORD
    LOCAL cellY:DWORD
    LOCAL totalCells:DWORD
    
    ; Inicializar todas las celdas
    mov i, 0
    .while i < 6    ; Para cada cara (gridIndex)
        mov j, 0
        .while j < 4    ; Para cada fila (cellY)
            mov k, 0
            .while k < 4    ; Para cada columna (cellX)
                ; Calcular offset en el array de celdas
                ; offset = (i * 4 * 4 + j * 4 + k) * 4
                mov eax, i
                mov ebx, 16    ; 4 * 4
                mul ebx
                mov cellOffset, eax
                
                mov eax, j
                mov ebx, 4
                mul ebx
                add cellOffset, eax
                
                mov ecx, k
                add cellOffset, ecx
                
                ; Multiplicar por 4 (tamaño de cada elemento)
                mov eax, cellOffset
                shl eax, 2    ; Multiplicar por 4
                mov cellOffset, eax
                
                ; Inicializar los valores
                mov ebx, offset cellStates
                add ebx, cellOffset
                
                ; hasMine = 0
                mov byte ptr [ebx], 0
                
                ; isRevealed = 0
                mov byte ptr [ebx+1], 0
                
                ; isFlagged = 0
                mov byte ptr [ebx+2], 0
                
                ; adjacentMines = 0
                mov byte ptr [ebx+3], 0
                
                inc k
            .endw
            inc j
        .endw
        inc i
    .endw
    
    ; Obtener la hora actual como semilla
    invoke GetTickCount
    mov seed, eax
    
    ; Colocar MINE_COUNT minas aleatoriamente
    mov eax, MINE_COUNT
    mov minesLeft, eax

    ; Total de celdas disponibles (4 caras x 4x4 celdas)
    mov eax, 4      ; Solo usaremos 4 caras para simplificar
    mov ebx, 16     ; 4x4 celdas por cara
    mul ebx
    mov totalCells, eax
    
    ; Colocar minas mientras queden por colocar
    .while minesLeft > 0
        ; Generar gridIndex aleatorio (0-3)
        invoke Random
        mov ebx, 4
        xor edx, edx
        div ebx
        mov gridIndex, edx    ; edx contiene el resto de la división (0-3)
        
        ; Generar cellX aleatorio (0-3)
        invoke Random
        mov ebx, 4
        xor edx, edx
        div ebx
        mov cellX, edx
        
        ; Generar cellY aleatorio (0-3)
        invoke Random
        mov ebx, 4
        xor edx, edx
        div ebx
        mov cellY, edx
        
        ; Calcular offset de la celda
        mov eax, gridIndex
        mov ebx, 16    ; 4 * 4
        mul ebx
        mov cellOffset, eax
        
        mov eax, cellY
        mov ebx, 4
        mul ebx
        add cellOffset, eax
        
        mov ecx, cellX
        add cellOffset, ecx
        
        ; Multiplicar por 4 (tamaño de cada elemento)
        mov eax, cellOffset
        shl eax, 2    ; Multiplicar por 4
        mov cellOffset, eax
        
        ; Verificar si ya hay una mina en esta celda
        mov ebx, offset cellStates
        add ebx, cellOffset
        
        mov al, byte ptr [ebx]    ; hasMine
        .if al == 0
            ; No hay mina, colocar una
            mov byte ptr [ebx], 1
            dec minesLeft
        .endif
    .endw
    
    ; Inicializar el estado del juego
    mov gameState.isRunning, 1
    invoke GetTickCount
    mov gameState.timeStarted, eax
    mov gameState.flagsPlaced, 0
    mov gameState.cellsRevealed, 0
    
    ret
InitGame endp

;-----------------------------------------------------------------------------
; ProcessCellClick - Procesa un clic en una celda
; Parámetros:
;   gridIndex - Índice de la cara (0-5)
;   cellX - Coordenada X de la celda (0-3)
;   cellY - Coordenada Y de la celda (0-3)
;   leftClick - 1 si es clic izquierdo, 0 si es clic derecho
; Retorna:
;   eax - 1 si se hizo algún cambio, 0 si no
;-----------------------------------------------------------------------------
ProcessCellClick proc gridIndex:DWORD, cellX:DWORD, cellY:DWORD, leftClick:DWORD
    LOCAL cellOffset:DWORD
    LOCAL cellX_val:BYTE
    LOCAL cellY_val:BYTE
    LOCAL isRevealed:BYTE
    LOCAL isFlagged:BYTE
    LOCAL hasMine:BYTE
    
    ; Validar parámetros
    mov eax, gridIndex
    .if eax >= 6
        xor eax, eax    ; Retornar 0 (sin cambios) si el índice de cara es inválido
        ret
    .endif
    
    mov eax, cellX
    .if eax >= 4
        xor eax, eax    ; Retornar 0 (sin cambios) si X es inválido
        ret
    .endif
    
    mov eax, cellY
    .if eax >= 4
        xor eax, eax    ; Retornar 0 (sin cambios) si Y es inválido
        ret
    .endif
    
    ; Calcular offset en el array de celdas
    ; offset = (gridIndex * 4 * 4 + cellY * 4 + cellX) * 4
    mov eax, gridIndex
    mov ebx, 16    ; 4 * 4
    mul ebx
    mov cellOffset, eax
    
    mov eax, cellY
    mov ebx, 4
    mul ebx
    add cellOffset, eax
    
    mov ecx, cellX
    add cellOffset, ecx
    
    ; Multiplicar por 4 (tamaño de cada elemento)
    mov eax, cellOffset
    shl eax, 2    ; Multiplicar por 4
    mov cellOffset, eax
    
    ; Obtener estado actual de la celda
    mov ebx, offset cellStates
    add ebx, cellOffset
    
    ; hasMine = cellStates[offset]
    mov al, byte ptr [ebx]
    mov hasMine, al
    
    ; isRevealed = cellStates[offset+1]
    mov al, byte ptr [ebx+1]
    mov isRevealed, al
    
    ; isFlagged = cellStates[offset+2]
    mov al, byte ptr [ebx+2]
    mov isFlagged, al
    
    ; Si es clic izquierdo
    mov eax, leftClick
    .if eax == 1
        ; Si la celda ya está revelada o tiene bandera, ignorar el clic
        mov al, isRevealed
        .if al != 0
            xor eax, eax    ; Retornar 0 (sin cambios)
            ret
        .endif
        
        mov al, isFlagged
        .if al != 0
            xor eax, eax    ; Retornar 0 (sin cambios)
            ret
        .endif
        
        ; Marcar la celda como revelada
        mov byte ptr [ebx+1], 1
        
        ; Incrementar el contador de celdas reveladas
        inc gameState.cellsRevealed
        
    ; Si es clic derecho
    .else
        ; Si la celda ya está revelada, ignorar el clic
        mov al, isRevealed
        .if al != 0
            xor eax, eax    ; Retornar 0 (sin cambios)
            ret
        .endif
        
        ; Alternar el estado de la bandera
        mov al, isFlagged
        .if al == 0
            ; Colocar bandera
            mov byte ptr [ebx+2], 1
            inc gameState.flagsPlaced
        .else
            ; Quitar bandera
            mov byte ptr [ebx+2], 0
            dec gameState.flagsPlaced
        .endif
    .endif
    
    ; Retornar 1 (se realizaron cambios)
    mov eax, 1
    ret
ProcessCellClick endp

;-----------------------------------------------------------------------------
; GetCellState - Obtiene el estado de una celda
; Parámetros:
;   gridIndex - Índice de la cara (0-5)
;   cellX - Coordenada X de la celda (0-3)
;   cellY - Coordenada Y de la celda (0-3)
;   pCellState - Puntero a una estructura Cell para recibir el estado
; Retorna:
;   eax - 1 si todo bien, 0 si hay error
;-----------------------------------------------------------------------------
GetCellState proc gridIndex:DWORD, cellX:DWORD, cellY:DWORD, pCellState:DWORD
    LOCAL cellOffset:DWORD
    
    ; Validar parámetros
    mov eax, gridIndex
    .if eax >= 6
        xor eax, eax    ; Retornar 0 (error) si el índice de cara es inválido
        ret
    .endif
    
    mov eax, cellX
    .if eax >= 4
        xor eax, eax    ; Retornar 0 (error) si X es inválido
        ret
    .endif
    
    mov eax, cellY
    .if eax >= 4
        xor eax, eax    ; Retornar 0 (error) si Y es inválido
        ret
    .endif
    
    ; Calcular offset en el array de celdas
    ; offset = (gridIndex * 4 * 4 + cellY * 4 + cellX) * 4
    mov eax, gridIndex
    mov ebx, 16    ; 4 * 4
    mul ebx
    mov cellOffset, eax
    
    mov eax, cellY
    mov ebx, 4
    mul ebx
    add cellOffset, eax
    
    mov ecx, cellX
    add cellOffset, ecx
    
    ; Multiplicar por 4 (tamaño de cada elemento)
    mov eax, cellOffset
    shl eax, 2    ; Multiplicar por 4
    mov cellOffset, eax
    
    ; Obtener puntero a la celda en el array
    mov ebx, offset cellStates
    add ebx, cellOffset
    
    ; Obtener puntero a la estructura Cell de destino
    mov edx, pCellState
    
    ; Copiar los datos
    ; hasMine
    mov al, byte ptr [ebx]
    mov byte ptr [edx], al
    
    ; isRevealed
    mov al, byte ptr [ebx+1]
    mov byte ptr [edx+1], al
    
    ; isFlagged
    mov al, byte ptr [ebx+2]
    mov byte ptr [edx+2], al
    
    ; adjacentMines
    mov al, byte ptr [ebx+3]
    mov byte ptr [edx+3], al
    
    ; Establecer los demás campos
    mov eax, gridIndex
    mov byte ptr [edx+4], al    ; face
    
    mov eax, cellX
    mov byte ptr [edx+5], al    ; x
    
    mov eax, cellY
    mov byte ptr [edx+6], al    ; y
    
    ; z por ahora lo dejamos en 0
    mov byte ptr [edx+7], 0     ; z
    
    ; Retornar 1 (éxito)
    mov eax, 1
    ret
GetCellState endp

end