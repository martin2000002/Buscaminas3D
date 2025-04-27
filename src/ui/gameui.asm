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
include src\ui\gameui.inc
include src\game\game.inc
include src\ui\grid.inc      ; Incluimos grid.inc para acceder a GetGridGeometry

; Variables externas definidas en main.asm
EXTERN gameState:GameState

.data
; Constantes para el mensaje y botón
MESSAGE_COLOR        EQU 00F5F5F5h   ; Color del texto del mensaje (blanco)
BUTTON_COLOR         EQU 003A3A3Ah   ; Color del botón (gris)
BUTTON_HOVER_COLOR   EQU 004D4D4Dh   ; Color del botón al pasar el mouse (gris más claro)
BUTTON_TEXT_COLOR    EQU 00F5F5F5h   ; Color del texto del botón (blanco)

; Texto del mensaje y botón
GameOverMessage      db "Perdiste!", 0
RestartButtonText    db "Reiniciar", 0

; Variables para la geometría del botón
buttonRect RECT <>

messageY    DWORD 0

; Variables para geometría del grid (cuando no tengamos acceso a GetGridGeometry)
gridStartY     DWORD 0
gridSize       DWORD 0

.code

;-----------------------------------------------------------------------------
; DrawGameMessage - Dibuja el mensaje de fin de juego
; Parámetros:
;   hWnd - Handle de la ventana
;   hdc - Contexto de dispositivo
;-----------------------------------------------------------------------------
DrawGameMessage proc hWnd:HWND, hdc:HDC
    LOCAL rect:RECT
    LOCAL topAreaHeight:DWORD
    LOCAL textWidth:DWORD
    LOCAL textHeight:DWORD
    LOCAL centerX:DWORD
    LOCAL oldFont:HFONT
    LOCAL newFont:HFONT
    LOCAL oldBkMode:DWORD
    LOCAL oldTextColor:DWORD
    LOCAL gridStart:DWORD
    
    ; Verificar si el juego ha terminado
    mov eax, gameState.isGameOver
    .if eax == 0
        ret     ; Si el juego no ha terminado, no mostrar mensaje
    .endif
    
    ; Obtener dimensiones de la ventana
    invoke GetClientRect, hWnd, addr rect
    
    ; Calcular la altura del área superior (header)
    mov eax, rect.bottom
    mov ebx, 10              ; Dividir por 10 para obtener el 10%
    xor edx, edx             ; Limpiar EDX para la división
    div ebx
    mov topAreaHeight, eax
    
    ; Intentar obtener la geometría del grid directamente
    invoke GetGridGeometry, addr gridStart, addr gridSize
    
    ; Establecer modo de fondo transparente para el texto
    invoke SetBkMode, hdc, TRANSPARENT
    mov oldBkMode, eax
    
    ; Configurar color del texto
    invoke SetTextColor, hdc, MESSAGE_COLOR
    mov oldTextColor, eax

    ; Calcular posición Y para el mensaje (centrado entre header y grid) B
    mov eax, gridStart
    shr eax, 1               ; Dividir por 2 para obtener el punto medio
    mov messageY, eax
    
    invoke CreateFont, topAreaHeight, 0, 0, 0, FW_BOLD, 0, 0, 0, \
                      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, \
                      CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
                      DEFAULT_PITCH or FF_DONTCARE, NULL
    mov newFont, eax
    
    ; Seleccionar la fuente en el contexto de dispositivo
    invoke SelectObject, hdc, newFont
    mov oldFont, eax
    
    ; Obtener dimensiones del texto
    invoke GetTextExtentPoint32, hdc, addr GameOverMessage, sizeof GameOverMessage - 1, addr textWidth
    mov eax, textWidth
    mov textWidth, eax       ; Guardar el ancho del texto
    
    ; Calcular posición X para centrar el texto
    mov eax, rect.right
    sub eax, textWidth
    shr eax, 1               ; Dividir por 2 para centrar
    mov centerX, eax
    
    ; Dibujar el mensaje
    invoke TextOut, hdc, centerX, messageY, addr GameOverMessage, sizeof GameOverMessage - 1
    
    ; Restaurar la configuración original
    invoke SelectObject, hdc, oldFont
    invoke DeleteObject, newFont
    invoke SetTextColor, hdc, oldTextColor
    invoke SetBkMode, hdc, oldBkMode
    
    ret
DrawGameMessage endp

;-----------------------------------------------------------------------------
; DrawRestartButton - Dibuja el botón de reinicio
; Parámetros:
;   hWnd - Handle de la ventana
;   hdc - Contexto de dispositivo
;-----------------------------------------------------------------------------
DrawRestartButton proc hWnd:HWND, hdc:HDC
    LOCAL rect:RECT
    LOCAL gridEndY:DWORD
    LOCAL buttonWidth:DWORD
    LOCAL buttonHeight:DWORD
    LOCAL centerX:DWORD
    LOCAL buttonY:DWORD
    LOCAL oldFont:HFONT
    LOCAL newFont:HFONT
    LOCAL oldBkMode:DWORD
    LOCAL oldTextColor:DWORD
    LOCAL textWidth:DWORD
    LOCAL textHeight:DWORD
    LOCAL textX:DWORD
    LOCAL textY:DWORD
    LOCAL hBrush:HBRUSH
    LOCAL hPen:HPEN
    LOCAL hOldBrush:HBRUSH
    LOCAL hOldPen:HPEN
    LOCAL gridStart:DWORD
    LOCAL gridSz:DWORD
    
    ; Verificar si el juego ha terminado
    mov eax, gameState.isGameOver
    .if eax == 0
        ret     ; Si el juego no ha terminado, no mostrar botón
    .endif
    
    ; Obtener dimensiones de la ventana
    invoke GetClientRect, hWnd, addr rect
    
    ; Definir dimensiones del botón (30% del ancho de la ventana y 8% de la altura)
    mov eax, rect.right
    mov ebx, 30
    mul ebx
    mov ebx, 100
    div ebx
    mov buttonWidth, eax
    
    mov eax, rect.bottom
    mov ebx, 8
    mul ebx
    mov ebx, 100
    div ebx
    mov buttonHeight, eax
    
    ; Intentar obtener la geometría del grid
    invoke GetGridGeometry, addr gridStart, addr gridSz
    
    ; Calcular el punto final Y del grid
    mov eax, gridStart
    add eax, gridSz
    mov gridEndY, eax
    
    ; Calcular el punto medio entre el final del grid y el final de la ventana
    mov eax, rect.bottom
    sub eax, gridEndY        ; Espacio disponible después del grid
    sub eax, buttonHeight    ; Restar altura del botón
    shr eax, 1               ; Dividir por 2 para centrar
    add eax, gridEndY        ; Añadir posición final del grid
    mov buttonY, eax
    
    ; Calcular posición X para centrar el botón
    mov eax, rect.right
    sub eax, buttonWidth
    shr eax, 1               ; Dividir por 2 para centrar
    mov centerX, eax
    
    ; Guardar las coordenadas del botón en la variable global
    mov eax, centerX
    mov buttonRect.left, eax
    
    mov eax, buttonY
    mov buttonRect.top, eax
    
    mov eax, centerX
    add eax, buttonWidth
    mov buttonRect.right, eax
    
    mov eax, buttonY
    add eax, buttonHeight
    mov buttonRect.bottom, eax
    
    ; Crear pincel y pluma para dibujar el botón
    invoke CreateSolidBrush, BUTTON_COLOR
    mov hBrush, eax
    
    invoke CreatePen, PS_SOLID, 1, BUTTON_COLOR
    mov hPen, eax
    
    ; Seleccionar pincel y pluma en el contexto de dispositivo
    invoke SelectObject, hdc, hBrush
    mov hOldBrush, eax
    
    invoke SelectObject, hdc, hPen
    mov hOldPen, eax
    
    ; Dibujar el rectángulo del botón (con esquinas redondeadas)
    invoke RoundRect, hdc, buttonRect.left, buttonRect.top, buttonRect.right, buttonRect.bottom, 10, 10
    
    ; Establecer modo de fondo transparente para el texto
    invoke SetBkMode, hdc, TRANSPARENT
    mov oldBkMode, eax
    
    ; Configurar color del texto
    invoke SetTextColor, hdc, BUTTON_TEXT_COLOR
    mov oldTextColor, eax
    
    ; Crear una fuente para el texto del botón
    mov eax, buttonHeight
    mov ebx, 60
    mul ebx
    mov ebx, 100
    div ebx                  ; 60% de la altura del botón
    mov textHeight, eax
    invoke CreateFont, textHeight, 0, 0, 0, FW_BOLD, 0, 0, 0, \
                      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, \
                      CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
                      DEFAULT_PITCH or FF_DONTCARE, NULL
    mov newFont, eax
    
    ; Seleccionar la fuente en el contexto de dispositivo
    invoke SelectObject, hdc, newFont
    mov oldFont, eax
    
    ; Obtener dimensiones del texto
    invoke GetTextExtentPoint32, hdc, addr RestartButtonText, sizeof RestartButtonText - 1, addr textWidth
    
    ; Calcular posición para centrar el texto en el botón
    mov eax, buttonRect.left
    add eax, buttonRect.right
    sub eax, textWidth
    shr eax, 1               ; (left + right - textWidth) / 2
    mov textX, eax
    
    mov eax, buttonRect.top
    add eax, buttonRect.bottom
    sub eax, textHeight
    shr eax, 1               ; (top + bottom - textHeight) / 2
    mov textY, eax
    
    ; Dibujar el texto
    invoke TextOut, hdc, textX, textY, addr RestartButtonText, sizeof RestartButtonText - 1
    
    ; Restaurar la configuración original
    invoke SelectObject, hdc, oldFont
    invoke DeleteObject, newFont
    invoke SetTextColor, hdc, oldTextColor
    invoke SetBkMode, hdc, oldBkMode
    
    ; Restaurar pincel y pluma originales
    invoke SelectObject, hdc, hOldBrush
    invoke DeleteObject, hBrush
    invoke SelectObject, hdc, hOldPen
    invoke DeleteObject, hPen
    
    ret
DrawRestartButton endp

;-----------------------------------------------------------------------------
; HandleButtonClick - Maneja el clic en el botón de reinicio
; Parámetros:
;   hWnd - Handle de la ventana
;   x, y - Coordenadas del clic
; Retorna:
;   eax - 1 si el clic fue procesado, 0 si no
;-----------------------------------------------------------------------------
HandleButtonClick proc hWnd:HWND, x:DWORD, y:DWORD
    LOCAL pt:POINT
    
    ; Verificar si el juego ha terminado
    mov eax, gameState.isGameOver
    .if eax == 0
        xor eax, eax        ; Si el juego no ha terminado, no procesar clic
        ret
    .endif
    
    ; Comprobar si el clic está dentro del botón
    mov eax, x
    mov pt.x, eax
    
    mov eax, y
    mov pt.y, eax
    
    ; Comprobar si el punto está dentro del rectángulo del botón
    mov eax, pt.x
    .if eax < buttonRect.left
        xor eax, eax        ; Fuera del botón
        ret
    .endif
    
    mov eax, pt.x
    .if eax > buttonRect.right
        xor eax, eax        ; Fuera del botón
        ret
    .endif
    
    mov eax, pt.y
    .if eax < buttonRect.top
        xor eax, eax        ; Fuera del botón
        ret
    .endif
    
    mov eax, pt.y
    .if eax > buttonRect.bottom
        xor eax, eax        ; Fuera del botón
        ret
    .endif
    
    ; El clic está dentro del botón, reiniciar el juego
    invoke InitGame
    
    ; Invalidar toda la ventana para volver a dibujar
    invoke InvalidateRect, hWnd, NULL, TRUE
    
    ; Clic procesado
    mov eax, 1
    ret
HandleButtonClick endp

end