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

debugNoAdyacentMinesStr db "(%d, %d, %d) -> SIN MINAS ADYACENTES", 0
debugMineStr db "(%d, %d, %d) -> MINA", 0
debugRevelada db "REVELADA", 0
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

                    .if lastCalculatedMines == 0
                        ; Depuración: celdas sin minas adyacentes
                        invoke wsprintf, ADDR buffer, ADDR debugNoAdyacentMinesStr, i, j, k
                        invoke OutputDebugString, ADDR buffer
                    .endif

                    ; Guardar el valor en la estructura
                    mov cl, lastCalculatedMines
                    mov ebx, cellPtr
                    mov (Cell PTR [ebx]).adjacentMines, cl

                .else
                    ; Si tiene mina, asignar valor especial (57)
                    mov ebx, cellPtr
                    mov (Cell PTR [ebx]).adjacentMines, 57
                    
                    ; Depuración: celda con mina
                    invoke wsprintf, ADDR buffer, ADDR debugMineStr, i, j, k
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
    mov gameState.timeStarted, 0
    mov gameState.flagsPlaced, 0
    mov gameState.cellsRevealed, 0
    mov gameState.isGameOver, 0   ; Inicializar el estado de fin de juego
    
    ret
InitGame endp

;-----------------------------------------------------------------------------
; FloodFill3D - Implementa el algoritmo de flood-fill en 3D
; Parámetros:
;   gridIndex - Índice de la cara (0-3)
;   cellX - Coordenada X de la celda (0-3)
;   cellY - Coordenada Y de la celda (0-3)
;-----------------------------------------------------------------------------
FloodFill3D proc gridIndex:DWORD, cellX:DWORD, cellY:DWORD
    LOCAL cellData:Cell
    LOCAL minGridIndex:DWORD
    LOCAL maxGridIndex:DWORD
    LOCAL minX:DWORD
    LOCAL maxX:DWORD
    LOCAL minY:DWORD
    LOCAL maxY:DWORD
    LOCAL dii:DWORD
    LOCAL dj:DWORD
    LOCAL dk:DWORD
    LOCAL newGridIndex:DWORD
    LOCAL newX:DWORD
    LOCAL newY:DWORD
    LOCAL cellChanged:DWORD
    
    ; 1) Validación de límites
    ; Verificar si la celda está fuera del tablero
    .if gridIndex >= 4     ; Solo usamos 4 caras (0-3)
        ret
    .endif
    
    .if cellX >= 4
        ret
    .endif
    
    .if cellY >= 4
        ret
    .endif
    
    ; Obtener el estado actual de la celda
    invoke GetCellState, gridIndex, cellX, cellY, addr cellData
    
    ; 2) Validar si ya está revelada o es una mina
    ; Si la celda ya está revelada, no hacer nada
    .if cellData.isRevealed != 0
        ret
    .endif
    
    ; Si la celda tiene una mina, no hacer nada
    .if cellData.hasMine != 0
        ret
    .endif
    
    ; 3) Revelar la celda
    ; Marcar la celda como revelada (no usar ProcessCellClick para evitar recursión infinita)
    ; Calcular offset en el array de celdas
    push eax
    push ebx
    push edx
    
    ; Calcular offset
    mov eax, gridIndex
    imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
    
    mov ebx, cellY
    imul ebx, 4           ; cellY * columnas por fila
    add eax, ebx
    
    add eax, cellX        ; + cellX
    
    ; Multiplicar por el tamaño de la estructura Cell
    mov ebx, TYPE Cell
    mul ebx
    
    ; Obtener puntero a la celda
    lea ebx, cellStates
    add ebx, eax
    
    ; Verificar si la celda ya estaba revelada
    mov al, (Cell PTR [ebx]).isRevealed
    mov cellChanged, 0
    .if al == 0
        ; No estaba revelada, marcarla como revelada
        mov (Cell PTR [ebx]).isRevealed, 1
        inc gameState.cellsRevealed
        mov cellChanged, 1

    .endif
    
    pop edx
    pop ebx
    pop eax
    
    ; 4) Si tiene minas adyacentes > 0, detenerse
    .if cellData.adjacentMines > 0
        ret
    .endif
    
    ; 5) Si no hubo cambios, detenerse (para evitar loops)
    .if cellChanged == 0
        ret
    .endif

    ; 6) Expandir en las 26 direcciones (o las que apliquen según los límites)
    ; Calcular límites para dii (gridIndex)
    mov eax, gridIndex
    .if eax == 0
        mov minGridIndex, 0
    .else
        mov eax, gridIndex
        dec eax
        mov minGridIndex, eax
    .endif
    
    mov eax, gridIndex
    inc eax
    .if eax >= 4     ; Limitamos a las 4 caras (0-3)
        mov maxGridIndex, 3
    .else
        mov maxGridIndex, eax
    .endif
    
    ; Calcular límites para dj (Y)
    mov eax, cellY
    .if eax == 0
        mov minY, 0
    .else
        mov eax, cellY
        dec eax
        mov minY, eax
    .endif
    
    mov eax, cellY
    inc eax
    .if eax >= 4
        mov maxY, 3
    .else
        mov maxY, eax
    .endif
    
    ; Calcular límites para dk (X)
    mov eax, cellX
    .if eax == 0
        mov minX, 0
    .else
        mov eax, cellX
        dec eax
        mov minX, eax
    .endif
    
    mov eax, cellX
    inc eax
    .if eax >= 4
        mov maxX, 3
    .else
        mov maxX, eax
    .endif
    
    ; Recorrer los 26 vecinos (dentro de los límites calculados)
    mov eax, minGridIndex
    mov dii, eax
    
    grid_loop:
        mov eax, dii
        cmp eax, maxGridIndex
        jg end_grid_loop
        
        mov eax, minY
        mov dj, eax
        
        y_loop:
            mov eax, dj
            cmp eax, maxY
            jg end_y_loop
            
            mov eax, minX
            mov dk, eax
            
            x_loop:
                mov eax, dk
                cmp eax, maxX
                jg end_x_loop
                
                ; Saltar la celda central (i,j,k)
                mov eax, dii
                .if eax == gridIndex
                    mov eax, dj
                    .if eax == cellY
                        mov eax, dk
                        .if eax == cellX
                            jmp next_cell
                        .endif
                    .endif
                .endif
                
                ; Llamar recursivamente a FloodFill3D para esta celda vecina
                mov eax, dii
                mov newGridIndex, eax
                
                mov eax, dj
                mov newY, eax
                
                mov eax, dk
                mov newX, eax
                
                invoke FloodFill3D, newGridIndex, newX, newY
                
                next_cell:
                inc dk
                jmp x_loop
                
            end_x_loop:
            inc dj
            jmp y_loop
            
        end_y_loop:
        inc dii
        jmp grid_loop
        
    end_grid_loop:
    
    ret
FloodFill3D endp

;-----------------------------------------------------------------------------
; GetElapsedTime - Calcula el tiempo transcurrido desde el inicio del juego
; Retorna:
;   eax - Minutos transcurridos (0-99)
;   edx - Segundos transcurridos (0-59)
;-----------------------------------------------------------------------------
GetElapsedTime proc
    LOCAL currentTime:DWORD
    LOCAL elapsedTime:DWORD
    LOCAL seconds:DWORD
    LOCAL minutes:DWORD
    
    ; Verificar si el juego está en ejecución
    mov eax, gameState.isRunning
    .if eax == 0
        ; Si el juego no está en ejecución, retornar 0:00
        xor eax, eax    ; 0 minutos
        xor edx, edx    ; 0 segundos
        ret
    .endif
    
    ; Verificar si el tiempo de inicio es válido
    mov eax, gameState.timeStarted
    .if eax == 0
        ; Si no se ha iniciado el timer, retornar 0:00
        xor eax, eax    ; 0 minutos
        xor edx, edx    ; 0 segundos
        ret
    .endif
    
    ; Obtener el tiempo actual
    invoke GetTickCount
    mov currentTime, eax
    
    ; Calcular el tiempo transcurrido en milisegundos
    mov eax, currentTime
    sub eax, gameState.timeStarted
    mov elapsedTime, eax
    
    ; Convertir a segundos (dividir por 1000)
    mov eax, elapsedTime
    mov ebx, 1000
    xor edx, edx
    div ebx
    mov seconds, eax
    
    ; Calcular minutos y segundos
    mov eax, seconds
    mov ebx, 60
    xor edx, edx
    div ebx
    
    ; eax = minutos, edx = segundos restantes
    mov minutes, eax
    mov seconds, edx    ; Guardar los segundos restantes (0-59)
    
    ; Limitar a 99 minutos
    .if minutes > 99
        mov minutes, 99
        mov seconds, 59    ; Mostrar 99:59 como máximo
    .endif
    
    ; Retornar: eax = minutos, edx = segundos
    mov eax, minutes
    mov edx, seconds
    
    ret
GetElapsedTime endp

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
    LOCAL cellChanged:DWORD
    
    ; Verificar si el juego ya terminó
    mov eax, gameState.isGameOver
    .if eax != 0
        xor eax, eax        ; El juego ya terminó, no procesar clic
        ret
    .endif
    
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
    
    ; Inicializar flag de cambios
    mov cellChanged, 0
    
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
        
        ; Verificar si no hay celdas reveladas aún
        mov eax, gameState.cellsRevealed
        add eax, gameState.timeStarted
        .if eax == 0
            ; Si no está establecido y es la primera celda, iniciar el timer
            invoke GetTickCount
            mov gameState.timeStarted, eax
        .endif
        
        ; Si la celda tiene 0 minas adyacentes, iniciar flood-fill 3D
        mov al, hasMine
        .if al == 0     ; No es mina
            mov al, adjacentMines
            .if al == 0     ; No tiene minas adyacentes
                ; En lugar de simplemente revelar esta celda, 
                ; iniciamos el algoritmo de flood-fill 3D
                invoke FloodFill3D, gridIndex, cellX, cellY
                mov cellChanged, 1
            .else
                ; Tiene minas adyacentes, solo revelar esta celda
                mov ebx, cellPtr
                mov (Cell PTR [ebx]).isRevealed, 1
                inc gameState.cellsRevealed
                mov cellChanged, 1
            .endif
        .else
            ; Es una mina, revelar esta celda y terminar el juego
            mov ebx, cellPtr
            mov (Cell PTR [ebx]).isRevealed, 1
            inc gameState.cellsRevealed
            mov cellChanged, 1
            
            ; Marcar el juego como terminado
            mov gameState.isGameOver, 1
            
            ; Revelar todas las minas para mostrarlas
            push eax
            push ebx
            push ecx
            push edx
            
            ; Revelar todas las minas
            ; Esta parte es opcional: revelar todas las minas al perder
            mov ecx, 0    ; gridIndex
            .while ecx < 4
                mov edx, 0    ; cellY
                .while edx < 4
                    mov eax, 0    ; cellX
                    .while eax < 4
                        ; Revisar si esta celda tiene mina
                        push eax
                        push ecx
                        push edx
                        
                        ; Calcular offset
                        mov eax, ecx
                        imul eax, 4 * 4       ; gridIndex * (filas por cara * columnas por cara)
                        
                        mov ebx, edx
                        imul ebx, 4           ; cellY * columnas por fila
                        add eax, ebx
                        
                        add eax, [esp+8]       ; + cellX (guardado en la pila)
                        
                        ; Multiplicar por el tamaño de la estructura Cell
                        mov ebx, TYPE Cell
                        mul ebx
                        
                        ; Obtener puntero a la celda
                        lea ebx, cellStates
                        add ebx, eax
                        
                        ; Revisar si tiene mina
                        mov al, (Cell PTR [ebx]).hasMine
                        .if al != 0
                            ; Si tiene mina, revelarla
                            mov (Cell PTR [ebx]).isRevealed, 1
                        .endif
                        
                        pop edx
                        pop ecx
                        pop eax
                        
                        inc eax
                    .endw
                    inc edx
                .endw
                inc ecx
            .endw
            
            pop edx
            pop ecx
            pop ebx
            pop eax
        .endif
        
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
            mov cellChanged, 1
        .else
            ; Quitar bandera
            mov (Cell PTR [ebx]).isFlagged, 0
            dec gameState.flagsPlaced
            mov cellChanged, 1
        .endif
    .endif
    
    ; Retornar 1 si se realizaron cambios, 0 si no
    mov eax, cellChanged
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
    
    ; Retornar 1 (éxito)
    mov eax, 1
    ret
GetCellState endp

end