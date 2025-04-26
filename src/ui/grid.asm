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
include src\ui\grid.inc
include src\game\game.inc  ; Incluir el módulo de lógica de juego

; Variables externas definidas en main.asm
EXTERN gameState:GameState

.data
; Constantes para el grid
GRID_CELLS          EQU 4           ; Número de celdas por lado (4x4)
GRID_COLOR          EQU 00000000h   ; Color de las líneas del grid (negro)
CELL_COLOR          EQU 00D3D3D3h   ; Color de fondo de las celdas (gris claro)
CELL_COLOR_CLICKED  EQU 0000FF00h   ; Color cuando se hace clic (verde)
CELL_COLOR_FLAGGED  EQU 000000FFh   ; Color cuando tiene bandera (rojo)

; Constantes definidas como porcentajes (multiplicadas por 100 para evitar decimales)
HORIZONTAL_MARGIN   EQU 5           ; 5% del ancho disponible entre cada grid
VERTICAL_MARGIN     EQU 15          ; 15% del alto disponible como margen vertical
CELL_PADDING_PCT    EQU 5           ; 5% del tamaño de la celda como padding

; Variables globales para la geometría del grid
gridGeometry STRUCT
    gridSize              DWORD ?   ; Tamaño de cada grid
    cellWidth             DWORD ?   ; Ancho de cada celda
    cellHeight            DWORD ?   ; Alto de cada celda
    startX                DWORD ?   ; Posición X inicial
    startY                DWORD ?   ; Posición Y inicial
    horizontalMarginPixels DWORD ?  ; Margen horizontal en píxeles
    topAreaHeight         DWORD ?   ; Altura del área superior (header)
gridGeometry ENDS

currentGeometry gridGeometry <>

.code

;-----------------------------------------------------------------------------
; DrawGrids - Dibuja las 4 matrices 4x4 en fila
; Parámetros:
;   hWnd - Handle de la ventana
;   hdc - Contexto de dispositivo
;-----------------------------------------------------------------------------
DrawGrids proc hWnd:HWND, hdc:HDC
    LOCAL rect:RECT
    LOCAL availableHeight:DWORD
    LOCAL availableWidth:DWORD
    LOCAL i:DWORD
    LOCAL currentX:DWORD
    
    ; Obtener dimensiones de la ventana
    invoke GetClientRect, hWnd, addr rect
    
    ; Calcular la altura del área superior (header)
    mov eax, rect.bottom
    mov ebx, 10              ; Dividir por 10 para obtener el 10%
    xor edx, edx             ; Limpiar EDX para la división
    div ebx
    mov currentGeometry.topAreaHeight, eax   ; Guardar altura del área superior
    
    ; Calcular el espacio disponible para los grids
    mov eax, rect.bottom
    sub eax, currentGeometry.topAreaHeight
    mov availableHeight, eax  ; Altura disponible
    
    mov eax, rect.right      ; Usar eax como intermediario
    mov availableWidth, eax   ; Ahora movemos el valor al destino
    
    ; Calcular márgenes en píxeles
    mov eax, availableWidth
    mov ebx, HORIZONTAL_MARGIN
    mul ebx
    mov ebx, 100
    div ebx
    mov currentGeometry.horizontalMarginPixels, eax
    
    mov eax, availableHeight
    mov ebx, VERTICAL_MARGIN
    mul ebx
    mov ebx, 100
    div ebx
    ; Guardar verticalMarginPixels para uso local
    mov edx, eax
    
    ; Calcular el tamaño del grid basado en el margen horizontal:
    ; gridSize = (anchoPantalla * (1 - 5 * MARGENHORIZONTAL)) / 4
    mov eax, currentGeometry.horizontalMarginPixels
    mov ebx, 5
    mul ebx
    ; eax = 5 * horizontalMarginPixels
    
    mov ebx, availableWidth
    sub ebx, eax
    ; ebx = availableWidth - 5 * horizontalMarginPixels
    
    mov eax, ebx
    mov ebx, 4
    div ebx
    ; eax = (availableWidth - 5 * horizontalMarginPixels) / 4
    
    ; Guardar horizontalGridSize para uso local
    mov ecx, eax
    
    ; Calcular el tamaño del grid basado en el margen vertical:
    ; gridSize = altoPantalla * (1 - 2 * MARGENVERTICAL)
    mov eax, edx  ; Restaurar verticalMarginPixels
    mov ebx, 2
    mul ebx
    ; eax = 2 * verticalMarginPixels
    
    mov ebx, availableHeight
    sub ebx, eax
    ; ebx = availableHeight - 2 * verticalMarginPixels
    
    ; Guardar verticalGridSize para uso local
    mov edx, ebx
    
    ; Elegir el menor de los dos tamaños
    mov eax, ecx  ; Restaurar horizontalGridSize
    .if eax <= edx    ; Comparar con verticalGridSize
        mov currentGeometry.gridSize, eax
    .else
        mov eax, edx  ; Usar verticalGridSize
        mov currentGeometry.gridSize, eax
    .endif
    
    ; Calcular tamaño de celda
    mov eax, currentGeometry.gridSize
    mov ebx, GRID_CELLS
    xor edx, edx
    div ebx
    mov currentGeometry.cellWidth, eax
    mov currentGeometry.cellHeight, eax
    
    ; Calcular posición inicial X (para centrar horizontalmente)
    mov eax, currentGeometry.gridSize
    mov ebx, 4
    mul ebx
    ; eax = gridSize * 4
    
    mov ebx, currentGeometry.horizontalMarginPixels
    imul ebx, 5
    add eax, ebx
    ; eax = gridSize * 4 + horizontalMarginPixels * 5
    
    mov ebx, availableWidth
    sub ebx, eax
    shr ebx, 1
    ; ebx = (availableWidth - (gridSize * 4 + horizontalMarginPixels * 5)) / 2
    
    mov eax, ebx
    add eax, currentGeometry.horizontalMarginPixels
    ; eax = (availableWidth - (gridSize * 4 + horizontalMarginPixels * 5)) / 2 + horizontalMarginPixels
    
    mov currentGeometry.startX, eax
    
    ; Calcular posición inicial Y (para centrar verticalmente)
    mov eax, availableHeight
    sub eax, currentGeometry.gridSize
    shr eax, 1
    add eax, currentGeometry.topAreaHeight
    mov currentGeometry.startY, eax
    
    ; Dibujar los 4 grids
    mov i, 0
    mov eax, currentGeometry.startX
    mov currentX, eax
    
    .while i < 4
        invoke DrawSingleGrid, hdc, currentX, currentGeometry.startY, currentGeometry.gridSize, currentGeometry.gridSize, i
        
        ; Avanzar a la siguiente posición X
        mov eax, currentX
        add eax, currentGeometry.gridSize
        add eax, currentGeometry.horizontalMarginPixels
        mov currentX, eax
        
        ; Incrementar contador
        inc i
    .endw
    
    ret
DrawGrids endp

;-----------------------------------------------------------------------------
; DrawSingleGrid - Dibuja una matriz 4x4 individual
; Parámetros:
;   hdc - Contexto de dispositivo
;   x, y - Coordenadas de la esquina superior izquierda
;   gridWidth, gridHeight - Dimensiones del grid
;   gridIndex - Índice del grid (0-3)
;-----------------------------------------------------------------------------
DrawSingleGrid proc hdc:HDC, x:DWORD, y:DWORD, gridWidth:DWORD, gridHeight:DWORD, gridIndex:DWORD
    LOCAL cellPadding:DWORD
    LOCAL row:DWORD
    LOCAL col:DWORD
    LOCAL cellX:DWORD
    LOCAL cellY:DWORD
    LOCAL hPen:HPEN
    LOCAL hBrush:HBRUSH
    LOCAL hOldPen:HPEN
    LOCAL hOldBrush:HBRUSH
    LOCAL rect:RECT
    LOCAL cellData:Cell      ; Para almacenar el estado de cada celda
    
    ; Calcular el padding de celda basado en el porcentaje
    mov eax, currentGeometry.cellWidth
    mov ebx, CELL_PADDING_PCT
    mul ebx
    mov ebx, 100
    div ebx
    mov cellPadding, eax
    
    ; Asegurar que el padding sea al menos 1 píxel
    .if cellPadding < 1
        mov cellPadding, 1
    .endif
    
    ; Crear pluma
    invoke CreatePen, PS_SOLID, 1, GRID_COLOR
    mov hPen, eax
    
    ; Seleccionar pluma en el DC
    invoke SelectObject, hdc, hPen
    mov hOldPen, eax
    
    ; Dibujar cada celda del grid
    mov row, 0
    .while row < GRID_CELLS
        mov col, 0
        .while col < GRID_CELLS
            ; Obtener estado de la celda
            invoke GetCellState, gridIndex, col, row, addr cellData
            
            ; Calcular posición de la celda
            mov eax, col
            mul currentGeometry.cellWidth
            add eax, x
            mov cellX, eax
            
            mov eax, row
            mul currentGeometry.cellHeight
            add eax, y
            mov cellY, eax
            
            ; Definir el rectángulo de la celda con padding
            mov eax, cellX
            add eax, cellPadding
            mov rect.left, eax
            
            mov eax, cellY
            add eax, cellPadding
            mov rect.top, eax
            
            mov eax, cellX
            add eax, currentGeometry.cellWidth
            sub eax, cellPadding
            mov rect.right, eax
            
            mov eax, cellY
            add eax, currentGeometry.cellHeight
            sub eax, cellPadding
            mov rect.bottom, eax
            
            ; Determinar el color según el estado de la celda
            mov al, cellData.isRevealed
            .if al != 0
                ; Celda revelada
                invoke CreateSolidBrush, CELL_COLOR_CLICKED
            .else
                mov al, cellData.isFlagged
                .if al != 0
                    ; Celda con bandera
                    invoke CreateSolidBrush, CELL_COLOR_FLAGGED
                .else
                    ; Celda normal
                    invoke CreateSolidBrush, CELL_COLOR
                .endif
            .endif
            mov hBrush, eax
            
            ; Seleccionar pincel
            invoke SelectObject, hdc, hBrush
            mov hOldBrush, eax
            
            ; Dibujar la celda
            invoke Rectangle, hdc, rect.left, rect.top, rect.right, rect.bottom
            
            ; Restaurar pincel original y liberar el creado
            invoke SelectObject, hdc, hOldBrush
            invoke DeleteObject, hBrush
            
            inc col
        .endw
        inc row
    .endw
    
    ; Restaurar pluma original
    invoke SelectObject, hdc, hOldPen
    
    ; Liberar recursos
    invoke DeleteObject, hPen
    
    ret
DrawSingleGrid endp


;-----------------------------------------------------------------------------
; HandleGridClick - Maneja un clic en el área del grid
; Parámetros:
;   hWnd - Handle de la ventana
;   x, y - Coordenadas del clic en la ventana
;   leftClick - 1 si es clic izquierdo, 0 si es clic derecho
; Retorna:
;   eax - 1 si el clic fue procesado, 0 si no
;-----------------------------------------------------------------------------
HandleGridClick proc hWnd:HWND, x:DWORD, y:DWORD, leftClick:DWORD
    LOCAL gridIndex:DWORD
    LOCAL cellX:DWORD
    LOCAL cellY:DWORD
    LOCAL currentGridX:DWORD
    LOCAL gridWidth:DWORD
    LOCAL clickX:DWORD
    LOCAL clickY:DWORD
    
    ; Verificar si el clic está en el área de juego
    mov eax, y
    mov ecx, currentGeometry.topAreaHeight
    .if eax < ecx
        xor eax, eax    ; Retornar 0 (fuera del área)
        ret
    .endif
    
    mov eax, currentGeometry.startY
    add eax, currentGeometry.gridSize
    mov ecx, y
    .if ecx > eax
        xor eax, eax    ; Retornar 0 (fuera del área)
        ret
    .endif
    
    mov eax, x
    mov ecx, currentGeometry.startX
    .if eax < ecx
        xor eax, eax    ; Retornar 0 (fuera del área)
        ret
    .endif
    
    ; Obtener el ancho total de los 4 grids con márgenes
    mov eax, currentGeometry.startX
    add eax, currentGeometry.gridSize
    add eax, currentGeometry.horizontalMarginPixels
    add eax, currentGeometry.gridSize
    add eax, currentGeometry.horizontalMarginPixels
    add eax, currentGeometry.gridSize
    add eax, currentGeometry.horizontalMarginPixels
    add eax, currentGeometry.gridSize
    
    mov ecx, x
    .if ecx > eax
        xor eax, eax    ; Retornar 0 (fuera del área)
        ret
    .endif
    
    ; Calcular posición Y relativa a la parte superior del área de juego
    mov eax, y
    sub eax, currentGeometry.startY
    mov clickY, eax
    
    ; Dividir por la altura de la celda para obtener cellY
    mov eax, clickY
    mov ecx, currentGeometry.cellHeight
    xor edx, edx
    div ecx
    mov cellY, eax
    
    ; Validar cellY
    mov eax, cellY
    .if eax >= 4
        xor eax, eax    ; Fuera del rango válido
        ret
    .endif
    
    ; Para determinar el grid y la celda X, recorremos los 4 grids
    mov gridIndex, 0
    mov eax, currentGeometry.startX
    mov currentGridX, eax
    
    ; Calcular cuánto mide un grid (tamaño del grid + margen)
    mov eax, currentGeometry.gridSize
    add eax, currentGeometry.horizontalMarginPixels
    mov gridWidth, eax
    
    ; Comprobar cada grid
    .while gridIndex < 4
        ; Comprobar si X está dentro de este grid
        mov eax, x
        mov ecx, currentGridX
        .if eax >= ecx
            mov eax, currentGridX
            add eax, currentGeometry.gridSize
            mov ecx, x
            .if ecx < eax
                ; El clic está en este grid
                
                ; Calcular la coordenada X relativa a este grid
                mov eax, x
                sub eax, currentGridX
                mov clickX, eax
                
                ; Dividir por el ancho de la celda para obtener cellX
                mov eax, clickX
                mov ecx, currentGeometry.cellWidth
                xor edx, edx
                div ecx
                mov cellX, eax
                
                ; Validar cellX
                mov eax, cellX
                .if eax >= 4
                    xor eax, eax    ; Fuera del rango válido
                    ret
                .endif
                
                ; Procesar el clic en la celda
                invoke ProcessCellClick, gridIndex, cellX, cellY, leftClick
                
                ; Si se realizó algún cambio, invalidar la ventana para repintar
                .if eax != 0
                    invoke InvalidateRect, hWnd, NULL, TRUE
                .endif
                
                ; Clic procesado
                mov eax, 1
                ret
            .endif
        .endif
        
        ; Pasar al siguiente grid
        mov eax, currentGridX
        add eax, gridWidth
        mov currentGridX, eax
        
        ; Incrementar índice
        inc gridIndex
    .endw
    
    ; Si llegamos aquí, el clic no está en ningún grid
    xor eax, eax
    ret
HandleGridClick endp

end