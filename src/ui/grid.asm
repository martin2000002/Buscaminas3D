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

; Variables externas definidas en main.asm
EXTERN gameState:GameState

.data
; Constantes para el grid
GRID_CELLS          EQU 4           ; Número de celdas por lado (4x4)
GRID_COLOR          EQU 00000000h   ; Color de las líneas del grid (negro)
CELL_COLOR          EQU 00D3D3D3h   ; Color de fondo de las celdas (gris claro)

; Constantes definidas como porcentajes (multiplicadas por 100 para evitar decimales)
HORIZONTAL_MARGIN   EQU 5           ; 5% del ancho disponible entre cada grid
VERTICAL_MARGIN     EQU 15          ; 15% del alto disponible como margen vertical
CELL_PADDING_PCT    EQU 5           ; 5% del tamaño de la celda como padding

.code

;-----------------------------------------------------------------------------
; DrawGrids - Dibuja las 4 matrices 4x4 en fila
; Parámetros:
;   hWnd - Handle de la ventana
;   hdc - Contexto de dispositivo
;-----------------------------------------------------------------------------
DrawGrids proc hWnd:HWND, hdc:HDC
    LOCAL rect:RECT
    LOCAL topAreaHeight:DWORD
    LOCAL availableHeight:DWORD
    LOCAL availableWidth:DWORD
    LOCAL gridSize:DWORD
    LOCAL horizontalGridSize:DWORD
    LOCAL verticalGridSize:DWORD
    LOCAL startX:DWORD
    LOCAL startY:DWORD
    LOCAL i:DWORD
    LOCAL currentX:DWORD
    LOCAL horizontalMarginPixels:DWORD
    LOCAL verticalMarginPixels:DWORD
    
    ; Obtener dimensiones de la ventana
    invoke GetClientRect, hWnd, addr rect
    
    ; Calcular la altura del área superior (header)
    mov eax, rect.bottom
    mov ebx, 10              ; Dividir por 10 para obtener el 10%
    xor edx, edx             ; Limpiar EDX para la división
    div ebx
    mov topAreaHeight, eax   ; Guardar altura del área superior
    
    ; Calcular el espacio disponible para los grids
    mov eax, rect.bottom
    sub eax, topAreaHeight
    mov availableHeight, eax  ; Altura disponible
    
    mov eax, rect.right      ; Usar eax como intermediario
    mov availableWidth, eax   ; Ahora movemos el valor al destino
    
    ; Calcular márgenes en píxeles
    mov eax, availableWidth
    mov ebx, HORIZONTAL_MARGIN
    mul ebx
    mov ebx, 100
    div ebx
    mov horizontalMarginPixels, eax
    
    mov eax, availableHeight
    mov ebx, VERTICAL_MARGIN
    mul ebx
    mov ebx, 100
    div ebx
    mov verticalMarginPixels, eax
    
    ; Calcular el tamaño del grid basado en el margen horizontal:
    ; gridSize = (anchoPantalla * (1 - 5 * MARGENHORIZONTAL)) / 4
    mov eax, horizontalMarginPixels
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
    
    mov horizontalGridSize, eax
    
    ; Calcular el tamaño del grid basado en el margen vertical:
    ; gridSize = altoPantalla * (1 - 2 * MARGENVERTICAL)
    mov eax, verticalMarginPixels
    mov ebx, 2
    mul ebx
    ; eax = 2 * verticalMarginPixels
    
    mov ebx, availableHeight
    sub ebx, eax
    ; ebx = availableHeight - 2 * verticalMarginPixels
    
    mov verticalGridSize, ebx
    
    ; Elegir el menor de los dos tamaños
    mov eax, horizontalGridSize
    .if eax <= verticalGridSize
        mov gridSize, eax
    .else
        mov eax, verticalGridSize
        mov gridSize, eax
    .endif
    
    ; Calcular posición inicial X (para centrar horizontalmente)
    mov eax, gridSize
    mov ebx, 4
    mul ebx
    ; eax = gridSize * 4
    
    mov ebx, horizontalMarginPixels
    imul ebx, 5
    add eax, ebx
    ; eax = gridSize * 4 + horizontalMarginPixels * 5
    
    mov ebx, availableWidth
    sub ebx, eax
    shr ebx, 1
    ; ebx = (availableWidth - (gridSize * 4 + horizontalMarginPixels * 5)) / 2
    
    mov eax, ebx
    add eax, horizontalMarginPixels
    ; eax = (availableWidth - (gridSize * 4 + horizontalMarginPixels * 5)) / 2 + horizontalMarginPixels
    
    mov startX, eax
    
    ; Calcular posición inicial Y (para centrar verticalmente)
    mov eax, availableHeight
    sub eax, gridSize
    shr eax, 1
    add eax, topAreaHeight
    mov startY, eax
    
    ; Dibujar los 4 grids
    mov i, 0
    mov eax, startX
    mov currentX, eax
    
    .while i < 4
        invoke DrawSingleGrid, hdc, currentX, startY, gridSize, gridSize
        
        ; Avanzar a la siguiente posición X
        mov eax, currentX
        add eax, gridSize
        add eax, horizontalMarginPixels
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
;-----------------------------------------------------------------------------
DrawSingleGrid proc hdc:HDC, x:DWORD, y:DWORD, gridWidth:DWORD, gridHeight:DWORD
    LOCAL cellWidth:DWORD
    LOCAL cellHeight:DWORD
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
    
    ; Calcular dimensiones de cada celda
    mov eax, gridWidth
    mov ebx, GRID_CELLS
    xor edx, edx
    div ebx
    mov cellWidth, eax
    
    mov eax, gridHeight
    mov ebx, GRID_CELLS
    xor edx, edx
    div ebx
    mov cellHeight, eax
    
    ; Calcular el padding de celda basado en el porcentaje
    mov eax, cellWidth
    mov ebx, CELL_PADDING_PCT
    mul ebx
    mov ebx, 100
    div ebx
    mov cellPadding, eax
    
    ; Asegurar que el padding sea al menos 1 píxel
    .if cellPadding < 1
        mov cellPadding, 1
    .endif
    
    ; Crear pluma y pincel
    invoke CreatePen, PS_SOLID, 1, GRID_COLOR
    mov hPen, eax
    
    invoke CreateSolidBrush, CELL_COLOR
    mov hBrush, eax
    
    ; Seleccionar objetos en el DC
    invoke SelectObject, hdc, hPen
    mov hOldPen, eax
    
    invoke SelectObject, hdc, hBrush
    mov hOldBrush, eax
    
    ; Dibujar cada celda del grid
    mov row, 0
    .while row < GRID_CELLS
        mov col, 0
        .while col < GRID_CELLS
            ; Calcular posición de la celda
            mov eax, col
            mul cellWidth
            add eax, x
            mov cellX, eax
            
            mov eax, row
            mul cellHeight
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
            add eax, cellWidth
            sub eax, cellPadding
            mov rect.right, eax
            
            mov eax, cellY
            add eax, cellHeight
            sub eax, cellPadding
            mov rect.bottom, eax
            
            ; Dibujar la celda
            invoke Rectangle, hdc, rect.left, rect.top, rect.right, rect.bottom
            
            inc col
        .endw
        inc row
    .endw
    
    ; Restaurar objetos originales
    invoke SelectObject, hdc, hOldPen
    invoke SelectObject, hdc, hOldBrush
    
    ; Liberar recursos
    invoke DeleteObject, hPen
    invoke DeleteObject, hBrush
    
    ret
DrawSingleGrid endp

end