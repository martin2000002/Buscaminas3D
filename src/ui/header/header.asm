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
include include\resources.inc

include src\ui\header\header.inc
include src\game\game.inc

EXTERN gameState:GameState

.data

FlagCountStr    db "  ", 0
TimerStr        db "     ", 0    ; Buffer para el tiempo "MM:SS"
FlagTemplate    db "%2d", 0
TimeTemplate    db "%02d:%02d", 0

PercentageGroupSpace   DWORD 20
IconTextSpace   DWORD 10

.data?
GroupSpace       DWORD ?

.code

; Función para dibujar el encabezado del juego
DrawHeader proc hWnd:HWND, hdc:HDC
    LOCAL rect:RECT
    LOCAL hBrush:HBRUSH
    LOCAL hFlagIcon:HICON
    LOCAL hClockIcon:HICON
    LOCAL hInstance:HINSTANCE
    LOCAL topAreaHeight:DWORD
    LOCAL centerYIcons:DWORD
    LOCAL centerYTexts:DWORD
    LOCAL timerTextWidth:DWORD
    LOCAL textWidth:DWORD
    LOCAL textHeight:DWORD
    LOCAL xPos:DWORD
    LOCAL iconSize:DWORD
    LOCAL oldFont:HFONT
    LOCAL newFont:HFONT
    LOCAL oldBkMode:DWORD
    LOCAL minutes:DWORD
    LOCAL seconds:DWORD
    LOCAL flags:DWORD
    
    ;-------------------------------------------------------------
    ; BACKGROUND DEL HEADER
    ;-------------------------------------------------------------
    invoke GetClientRect, hWnd, addr rect
    mov eax, rect.bottom
    mov ebx, 10              ; Dividir por 10 para obtener el 10%
    xor edx, edx            ; Limpiar EDX para la división
    div ebx
    mov topAreaHeight, eax  ; Guardar altura del área superior
    mov rect.bottom, eax    ; Altura del 10% del alto total
    
    ; Crear un pincel para rellenar el rectángulo
    invoke CreateSolidBrush, SECONDARY_COLOR_100
    mov hBrush, eax
    
    ; Rellenar el rectángulo con el pincel
    invoke FillRect, hdc, addr rect, hBrush
    
    ; Liberar el pincel
    invoke DeleteObject, hBrush

    ;-------------------------------------------------------------
    ; ACTUALIZAR TEXTO DEL CONTADOR DE BANDERAS Y TIMER
    ;-------------------------------------------------------------
    ; Actualizar contador de banderas (mostrar MINE_COUNT - flagsPlaced)
    mov eax, MINE_COUNT
    sub eax, gameState.flagsPlaced
    mov flags, eax
    invoke wsprintf, addr FlagCountStr, addr FlagTemplate, flags
     
    ; Verificar si el temporizador está activo
    mov eax, gameState.timeStarted
    .if eax == 0
        ; Si el timer no está activo, mostrar "00:00"
        mov minutes, 0
        mov seconds, 0
    .else
        ; Obtener tiempo transcurrido
        invoke GetElapsedTime
        mov minutes, eax
        mov seconds, edx
    .endif
    
    ; Formatear el tiempo como "MM:SS"
    invoke wsprintf, addr TimerStr, addr TimeTemplate, minutes, seconds
    
    ;-------------------------------------------------------------
    ; MEDIDAS PARA ALINEACIONES
    ;-------------------------------------------------------------
    ; Anchos de textos
    invoke GetTextExtentPoint32, hdc, ADDR FlagCountStr, 3, ADDR textWidth
    invoke GetTextExtentPoint32, hdc, ADDR TimerStr, 5, ADDR timerTextWidth
    
    ; Anchos/Largos de iconos
    mov eax, topAreaHeight
    mov ebx, 8          ; Multiplicar por 0.8 (8/10)
    mul ebx
    mov ebx, 10
    div ebx              ; eax = topAreaHeight * 0.8
    mov iconSize, eax

    ; Espacio entre grupos
    mov eax, rect.right
    mov ebx, PercentageGroupSpace
    mul ebx
    mov ebx, 100
    div ebx
    mov GroupSpace, eax
    
    ;-------------------------------------------------------------
    ; CONFIGURACION DE FUENTE
    ;-------------------------------------------------------------

    ; Establecer modo de fondo transparente para el texto
    invoke SetBkMode, hdc, TRANSPARENT
    mov oldBkMode, eax
    
    ; Crear una fuente para el texto con tamaño proporcional al 80% de la altura
    ; Altura de la fuente = 80% de la altura del header * 0.7 (para proporción)
    mov eax, iconSize
    mov ebx, 7
    mul ebx
    mov ebx, 10
    div ebx              ; eax = iconSize * 0.7 (70% del tamaño del icono)
    mov textHeight, eax
    
    ; Establecer el color del texto a blanco hueso para mejor contraste con el fondo azul
    invoke SetTextColor, hdc, TEXT_COLOR

    invoke CreateFont, textHeight, 0, 0, 0, FW_BOLD, 0, 0, 0, \
                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, \
                    CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
                    DEFAULT_PITCH or FF_DONTCARE, NULL
    mov newFont, eax
    
    ; Seleccionar la nueva fuente en el contexto de dispositivo
    invoke SelectObject, hdc, newFont
    mov oldFont, eax

    ;-------------------------------------------------------------
    ; CALCULO DE ALINEACIONES VERTICALES
    ;-------------------------------------------------------------

    ; Calcular posición vertical para centrar el texto con el icono
    mov eax, topAreaHeight
    sub eax, textHeight
    shr eax, 1           ; Dividir por 2 para centrar
    mov centerYTexts, eax

    ; Posicion centrada de y para iconos
    mov eax, topAreaHeight
    sub eax, iconSize
    shr eax, 1          ; Dividir por 2
    mov centerYIcons, eax
    

    ;-------------------------------------------------------------
    ; CALCULO DE ALINEACION HORIZONTAL
    ;-------------------------------------------------------------
    
    ; Calcular ancho total de cada grupo:
    ; Grupo flag: iconSize + 10 (espacio) + textWidth
    mov eax, iconSize
    add eax, IconTextSpace
    add eax, textWidth

    ; Grupo clock: iconSize + 10 (espacio) + timerTextWidth
    mov ebx, iconSize
    add ebx, IconTextSpace
    add ebx, timerTextWidth

    ; Espacio entre los dos grupos (150 píxeles)
    mov ecx, GroupSpace

    ; Ancho total de ambos grupos
    add eax, ecx
    add eax, ebx

    ; Calcular punto de inicio (centro - ancho_total/2)
    mov edx, rect.right
    sub edx, eax
    shr edx, 1          ; edx = centro - ancho_total/2 (para centrar todo)

    ; Posición inicial para el icono de bandera
    mov xPos, edx

    ;-------------------------------------------------------------
    ; MOSTRAR GRUPO FLAG
    ;-------------------------------------------------------------

    ; Obtener la instancia actual
    invoke GetWindowLong, hWnd, GWL_HINSTANCE
    mov hInstance, eax
    
    ; Cargar el ícono de bandera
    invoke LoadImage, hInstance, IDI_FLAG, IMAGE_ICON, iconSize, iconSize, LR_DEFAULTCOLOR
    mov hFlagIcon, eax
    
    ; Dibujar el ícono de bandera
    invoke DrawIconEx, hdc, xPos, centerYIcons, hFlagIcon, iconSize, iconSize, 0, NULL, DI_NORMAL
    
    ; Posición para el texto del contador (icono + espacio)
    mov eax, iconSize      ; Cargamos el valor de iconSize en eax
    add xPos, eax          ; Sumamos eax a xPos
    mov ebx, IconTextSpace
    add xPos, ebx
    invoke TextOut, hdc, xPos, centerYTexts, addr FlagCountStr, 3

    ;-------------------------------------------------------------
    ; MOSTRAR GRUPO CLOCK
    ;-------------------------------------------------------------

    ; Posición para el icono de reloj (contador + espacio150)
    mov eax, textWidth      ; Cargamos el valor de iconSize en eax
    add xPos, eax          ; Sumamos eax a xPos
    mov ebx, GroupSpace
    add xPos, ebx
    mov ebx, IconTextSpace
    sub xPos, ebx            ; Restamos 10 porque ya sumamos 10 después del icono de bandera

    ; Cargar el ícono de reloj
    invoke LoadImage, hInstance, IDI_CLOCK, IMAGE_ICON, iconSize, iconSize, LR_DEFAULTCOLOR
    mov hClockIcon, eax
    
    ; Dibujar el ícono de reloj
    invoke DrawIconEx, hdc, xPos, centerYIcons, hClockIcon, iconSize, iconSize, 0, NULL, DI_NORMAL

    ; Posición para el texto del timer (reloj + espacio)
    mov eax, iconSize      ; Cargamos el valor de iconSize en eax
    add xPos, eax          ; Sumamos eax a xPos
    mov ebx, IconTextSpace
    add xPos, ebx
    invoke TextOut, hdc, xPos, centerYTexts, addr TimerStr, 5
    
    ; Restaurar la fuente original y el modo de fondo
    invoke SelectObject, hdc, oldFont
    invoke SetBkMode, hdc, oldBkMode
    
    ; Liberar la fuente creada
    invoke DeleteObject, newFont
    
    ; Liberar los íconos
    invoke DestroyIcon, hFlagIcon
    invoke DestroyIcon, hClockIcon
    
    ret
DrawHeader endp

end