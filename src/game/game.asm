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
lastCalculatedMines BYTE 0  ; Variable global para almacenar el último valor calculado

debugWriteStr db "ESCRITURA: cara=%d, y=%d, x=%d, offset=%d, valor=%d", 0
debugReadStr db "LECTURA: cara=%d, y=%d, x=%d, offset=%d, valor=%d", 0
debugCalcStr db "CALCULO: cara=%d, y=%d, x=%d, resultado=%d", 0
buffer db 256 dup(?)

; Variables para generación aleatoria
seed DWORD 12345       ; Semilla para generación de números aleatorios

.data?
; Nuevo arreglo basado en la estructura
cellStates Cell 6 * 4 * 4 dup(<>)  ; 6 caras * 4x4 celdas por cara

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
; CalculateAdjacentMines - Calcula el número de minas adyacentes para una celda
; Parámetros:
;   gridIndex - Índice de la cara (0-3)
;   cellX - Coordenada X de la celda (0-3)
;   cellY - Coordenada Y de la celda (0-3)
; Retorna:
;   eax - Número de minas adyacentes
;-----------------------------------------------------------------------------
CalculateAdjacentMines proc gridIndex:DWORD, cellY:DWORD, cellX:DWORD
    LOCAL mineCount:BYTE
    LOCAL iAnalisis:DWORD
    LOCAL jAnalisis:DWORD
    LOCAL kAnalisis:DWORD
    LOCAL iAnalisisInicial:DWORD
    LOCAL jAnalisisInicial:DWORD
    LOCAL kAnalisisInicial:DWORD
    LOCAL iAnalisisFinal:DWORD
    LOCAL jAnalisisFinal:DWORD
    LOCAL kAnalisisFinal:DWORD
    LOCAL adjacentCellOffset:DWORD
    LOCAL adjacentCellPtr:DWORD
    LOCAL hasMine:BYTE
    
    ; Inicializar contador de minas
    mov mineCount, 0
    
    ; Calcular los límites de análisis para i (gridIndex)
    mov eax, gridIndex
    .if eax == 0
        mov iAnalisisInicial, 0
    .else
        mov eax, gridIndex
        dec eax
        mov iAnalisisInicial, eax
    .endif
    
    mov eax, gridIndex
    inc eax
    .if eax >= 4     ; Solo analizamos hasta 3 (las primeras 4 caras)
        mov iAnalisisFinal, 3
    .else
        mov iAnalisisFinal, eax
    .endif
    
    ; Recorrer las celdas adyacentes (incluyendo diagonales)
    mov eax, iAnalisisInicial
    mov iAnalisis, eax
    
    i_loop:
        mov eax, iAnalisis
        cmp eax, iAnalisisFinal
        jg end_i_loop      ; Salir si iAnalisis > iAnalisisFinal
        
        ; Calcular los límites de análisis para j (y)
        mov eax, cellY
        .if eax == 0
            mov jAnalisisInicial, 0
        .else
            mov eax, cellY
            dec eax
            mov jAnalisisInicial, eax
        .endif
        
        mov eax, cellY
        inc eax
        .if eax >= 4
            mov jAnalisisFinal, 3
        .else
            mov jAnalisisFinal, eax
        .endif
        
        mov eax, jAnalisisInicial
        mov jAnalisis, eax
        
        j_loop:
            mov eax, jAnalisis
            cmp eax, jAnalisisFinal
            jg end_j_loop  ; Salir si jAnalisis > jAnalisisFinal
            
            ; Calcular los límites de análisis para k (x)
            mov eax, cellX
            .if eax == 0
                mov kAnalisisInicial, 0
            .else
                mov eax, cellX
                dec eax
                mov kAnalisisInicial, eax
            .endif
            
            mov eax, cellX
            inc eax
            .if eax >= 4
                mov kAnalisisFinal, 3
            .else
                mov kAnalisisFinal, eax
            .endif
            
            mov eax, kAnalisisInicial
            mov kAnalisis, eax
            
            k_loop:
                mov eax, kAnalisis
                cmp eax, kAnalisisFinal
                jg end_k_loop  ; Salir si kAnalisis > kAnalisisFinal
                
                ; Si es la celda actual, saltarla
                mov eax, iAnalisis
                .if eax == gridIndex
                    mov eax, jAnalisis
                    .if eax == cellY
                        mov eax, kAnalisis
                        .if eax == cellX
                            ; Es la celda central, saltarla
                            jmp nextCell
                        .endif
                    .endif
                .endif
                
                ; Calcular offset de la celda adyacente
                ; Nuevo cálculo del offset usando tamaño de estructura
                mov eax, iAnalisis
                imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
                
                mov ebx, jAnalisis
                imul ebx, 4           ; cellY * columnas por fila
                add eax, ebx
                
                add eax, kAnalisis    ; + cellX
                
                ; Multiplicar por el tamaño de la estructura Cell (4 bytes)
                mov ebx, TYPE Cell
                mul ebx
                mov adjacentCellOffset, eax
                
                ; Obtener puntero a la celda adyacente
                lea ebx, cellStates
                add ebx, adjacentCellOffset
                mov adjacentCellPtr, ebx
                
                ; Verificar si esta celda adyacente tiene mina
                mov ebx, adjacentCellPtr
                ; hasMine = cellStates[offset].hasMine
                mov al, (Cell PTR [ebx]).hasMine
                mov hasMine, al
                
                ; Si tiene mina, incrementar contador
                .if hasMine != 0
                    inc mineCount
                .endif
                
                nextCell:
                    inc kAnalisis
                    jmp k_loop
                    
            end_k_loop:
            
            inc jAnalisis
            jmp j_loop
            
        end_j_loop:
        
        inc iAnalisis
        jmp i_loop
        
    end_i_loop:
    
    ; Retornar el número de minas adyacentes
    mov cl, mineCount
    mov lastCalculatedMines, cl  ; Guardar en variable global
    ret
CalculateAdjacentMines endp

;-----------------------------------------------------------------------------
; InitGame - Inicializa el estado del juego
;-----------------------------------------------------------------------------
InitGame proc
    LOCAL i:DWORD
    LOCAL j:DWORD
    LOCAL k:DWORD
    LOCAL cellOffset:DWORD
    LOCAL cellPtr:DWORD
    LOCAL minesLeft:DWORD
    LOCAL gridIndex:DWORD
    LOCAL cellX:DWORD
    LOCAL cellY:DWORD
    LOCAL totalCells:DWORD
    ; depuracion
    LOCAL adyacentMines:DWORD
    
    ; Inicializar todas las celdas
    mov i, 0
    .while i < 6    ; Para cada cara (gridIndex)
        mov j, 0
        .while j < 4    ; Para cada fila (cellY)
            mov k, 0
            .while k < 4    ; Para cada columna (cellX)
                ; Calcular offset en el array de celdas
                ; Nuevo cálculo del offset usando tamaño de estructura
                mov eax, i
                imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
                
                mov ebx, j
                imul ebx, 4           ; cellY * columnas por fila
                add eax, ebx
                
                add eax, k            ; + cellX
                
                ; Multiplicar por el tamaño de la estructura Cell (4 bytes)
                mov ebx, TYPE Cell
                mul ebx
                mov cellOffset, eax
                
                ; Obtener puntero a la celda
                lea ebx, cellStates
                add ebx, cellOffset
                mov cellPtr, ebx
                
                ; Inicializar los valores
                mov ebx, cellPtr
                
                ; hasMine = 0
                mov (Cell PTR [ebx]).hasMine, 0
                
                ; isRevealed = 0
                mov (Cell PTR [ebx]).isRevealed, 0
                
                ; isFlagged = 0
                mov (Cell PTR [ebx]).isFlagged, 0
                
                ; adjacentMines = 0
                mov (Cell PTR [ebx]).adjacentMines, 0
                
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
        ; Nuevo cálculo del offset usando tamaño de estructura
        mov eax, gridIndex
        imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
        
        mov ebx, cellY
        imul ebx, 4           ; cellY * columnas por fila
        add eax, ebx
        
        add eax, cellX        ; + cellX
        
        ; Multiplicar por el tamaño de la estructura Cell (4 bytes)
        mov ebx, TYPE Cell
        mul ebx
        mov cellOffset, eax
        
        ; Obtener puntero a la celda
        lea ebx, cellStates
        add ebx, cellOffset
        mov cellPtr, ebx
        
        ; Verificar si ya hay una mina en esta celda
        mov ebx, cellPtr
        
        ; Verificar hasMine
        mov al, (Cell PTR [ebx]).hasMine
        .if al == 0
            ; No hay mina, colocar una
            mov (Cell PTR [ebx]).hasMine, 1
            dec minesLeft
        .endif
    .endw
    
    ; Calcular el número de minas adyacentes para cada celda
    mov i, 0
    .while i < 4    ; Para cada cara (solo 4 primeras caras)
        mov j, 0
        .while j < 4    ; Para cada fila
            mov k, 0
            .while k < 4    ; Para cada columna
                ; Calcular offset en el array de celdas
                ; Nuevo cálculo del offset usando tamaño de estructura
                mov eax, i
                imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
                
                mov ebx, j
                imul ebx, 4           ; cellY * columnas por fila
                add eax, ebx
                
                add eax, k            ; + cellX
                
                ; Multiplicar por el tamaño de la estructura Cell (4 bytes)
                mov ebx, TYPE Cell
                mul ebx
                mov cellOffset, eax
                
                ; Obtener puntero a la celda
                lea ebx, cellStates
                add ebx, cellOffset
                mov cellPtr, ebx
                
                ; Si la celda no tiene mina, calcular minas adyacentes
                mov ebx, cellPtr
                mov al, (Cell PTR [ebx]).hasMine
                .if al == 0
                    ; Calcular minas adyacentes
                    invoke CalculateAdjacentMines, i, j, k

                    ; Mostrar el resultado del cálculo para depuración
                    movzx eax, lastCalculatedMines
                    mov adyacentMines, eax
                    invoke wsprintf, ADDR buffer, ADDR debugCalcStr, i, j, k, adyacentMines
                    invoke OutputDebugString, ADDR buffer

                    ; Guardar el valor en la estructura
                    mov cl, lastCalculatedMines
                    mov ebx, cellPtr
                    mov (Cell PTR [ebx]).adjacentMines, cl

                    ; Verificar si se guardó correctamente
                    movzx eax, (Cell PTR [ebx]).adjacentMines
                    mov adyacentMines, eax
                    invoke wsprintf, ADDR buffer, ADDR debugWriteStr, i, j, k, cellOffset, adyacentMines
                    invoke OutputDebugString, ADDR buffer
                .else
                    ; Si tiene mina, asignar valor especial (1)
                    mov ebx, cellPtr
                    mov (Cell PTR [ebx]).adjacentMines, 1
                    
                    ; ----- DEPURACIÓN: Verificar asignación de valor especial -----
                    movzx eax, (Cell PTR [ebx]).adjacentMines
                    mov adyacentMines, eax
                    invoke wsprintf, ADDR buffer, ADDR debugCalcStr, i, j, k, adyacentMines
                    invoke OutputDebugString, ADDR buffer
                .endif
                
                inc k
            .endw
            inc j
        .endw
        inc i
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
    LOCAL cellPtr:DWORD
    LOCAL cellX_val:BYTE
    LOCAL cellY_val:BYTE
    LOCAL isRevealed:BYTE
    LOCAL isFlagged:BYTE
    LOCAL hasMine:BYTE
    LOCAL adjacentMines:BYTE
        ; Variables temporales para depuración (DWORD)
    LOCAL hasMine_dw:DWORD
    LOCAL isRevealed_dw:DWORD
    LOCAL isFlagged_dw:DWORD
    LOCAL adjacentMines_dw:DWORD
    
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
    ; Nuevo cálculo del offset usando tamaño de estructura
    mov eax, gridIndex
    imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
    
    mov ebx, cellY
    imul ebx, 4           ; cellY * columnas por fila
    add eax, ebx
    
    add eax, cellX        ; + cellX
    
    ; Multiplicar por el tamaño de la estructura Cell (4 bytes)
    mov ebx, TYPE Cell
    mul ebx
    mov cellOffset, eax
    
    ; Obtener puntero a la celda
    lea ebx, cellStates
    add ebx, cellOffset
    mov cellPtr, ebx
    
    ; Obtener estado actual de la celda
    mov ebx, cellPtr
    
    ; hasMine = cellStates[offset].hasMine
    mov al, (Cell PTR [ebx]).hasMine
    mov hasMine, al
    
    ; isRevealed = cellStates[offset].isRevealed
    mov al, (Cell PTR [ebx]).isRevealed
    mov isRevealed, al
    
    ; isFlagged = cellStates[offset].isFlagged
    mov al, (Cell PTR [ebx]).isFlagged
    mov isFlagged, al

    ; adjacentMines = cellStates[offset].adjacentMines
    mov al, (Cell PTR [ebx]).adjacentMines
    mov adjacentMines, al
    
    ; ----- DEPURACIÓN: Verificar si se lee correctamente -----
    movzx eax, adjacentMines
    mov adjacentMines_dw, eax

    invoke wsprintf, ADDR buffer, ADDR debugReadStr, gridIndex, cellY, cellX, cellOffset, adjacentMines_dw
    invoke OutputDebugString, ADDR buffer
    
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
        mov ebx, cellPtr
        mov (Cell PTR [ebx]).isRevealed, 1
        
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
        mov ebx, cellPtr
        .if al == 0
            ; Colocar bandera
            mov (Cell PTR [ebx]).isFlagged, 1
            inc gameState.flagsPlaced
        .else
            ; Quitar bandera
            mov (Cell PTR [ebx]).isFlagged, 0
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
    LOCAL cellPtr:DWORD
    
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
    ; Nuevo cálculo del offset usando tamaño de estructura
    mov eax, gridIndex
    imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
    
    mov ebx, cellY
    imul ebx, 4           ; cellY * columnas por fila
    add eax, ebx
    
    add eax, cellX        ; + cellX
    
    ; Multiplicar por el tamaño de la estructura Cell (4 bytes)
    mov ebx, TYPE Cell
    mul ebx
    mov cellOffset, eax
    
    ; Obtener puntero a la celda
    lea ebx, cellStates
    add ebx, cellOffset
    mov cellPtr, ebx
    
    ; Obtener puntero a la estructura Cell de destino
    mov edx, pCellState
    
    ; Copiar los datos
    mov ebx, cellPtr
    
    ; hasMine
    mov al, (Cell PTR [ebx]).hasMine
    mov byte ptr [edx], al
    
    ; isRevealed
    mov al, (Cell PTR [ebx]).isRevealed
    mov byte ptr [edx+1], al
    
    ; isFlagged
    mov al, (Cell PTR [ebx]).isFlagged
    mov byte ptr [edx+2], al
    
    ; adjacentMines
    mov al, (Cell PTR [ebx]).adjacentMines
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