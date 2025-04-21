; header.asm - Implementación del encabezado de la interfaz para Buscaminas 3D
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
include include\resource.inc

include src\ui\header.inc

; Variables externas definidas en main.asm
EXTERN gameState:GameState

.data
; Color para el área de interfaz superior
UI_BRUSH_COLOR  EQU 00F0F0F0h  ; Color gris claro

; Strings para mostrar
FlagCountStr    db "10", 0
TimerStr        db "00:00", 0

.code

; Función para dibujar el encabezado del juego
DrawHeader proc hWnd:HWND, hdc:HDC
    LOCAL rect:RECT
    LOCAL hBrush:HBRUSH
    LOCAL hFlagIcon:HICON
    LOCAL hClockIcon:HICON
    LOCAL hInstance:HINSTANCE
    LOCAL topAreaHeight:DWORD
    LOCAL centerY:DWORD
    LOCAL timerTextWidth:DWORD
    LOCAL textWidth:DWORD
    LOCAL textHeight:DWORD
    LOCAL xPos:DWORD
    LOCAL iconSize:DWORD
    LOCAL oldFont:HFONT
    LOCAL newFont:HFONT
    LOCAL oldBkMode:DWORD
    
    ; Crear un rectángulo para el área de interfaz superior (10% del alto de la ventana)
    invoke GetClientRect, hWnd, addr rect
    mov eax, rect.bottom
    mov ebx, 10              ; Dividir por 10 para obtener el 10%
    xor edx, edx            ; Limpiar EDX para la división
    div ebx
    mov topAreaHeight, eax  ; Guardar altura del área superior
    mov rect.bottom, eax    ; Altura del 10% del alto total
    
    ; Crear un pincel para rellenar el rectángulo
    invoke CreateSolidBrush, UI_BRUSH_COLOR
    mov hBrush, eax
    
    ; Rellenar el rectángulo con el pincel
    invoke FillRect, hdc, addr rect, hBrush
    
    ; Liberar el pincel
    invoke DeleteObject, hBrush
    
    ; Obtener ancho del área cliente
    invoke GetClientRect, hWnd, addr rect
    
    ; Ajustar tamaño de icono al 80% de la altura del área superior
    mov eax, topAreaHeight
    mov ebx, 8          ; Multiplicar por 0.8 (8/10)
    mul ebx
    mov ebx, 10
    div ebx              ; eax = topAreaHeight * 0.8
    mov iconSize, eax
    
    ; Calcular posición vertical centrada para los íconos y texto
    mov eax, topAreaHeight
    sub eax, iconSize
    shr eax, 1          ; Dividir por 2
    mov centerY, eax    ; centerY es la posición Y para los íconos
    
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
    
    invoke CreateFont, eax, 0, 0, 0, FW_BOLD, 0, 0, 0, \
                      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, \
                      CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
                      DEFAULT_PITCH or FF_DONTCARE, NULL
    mov newFont, eax
    
    ; Seleccionar la nueva fuente en el contexto de dispositivo
    invoke SelectObject, hdc, newFont
    mov oldFont, eax
    
    ; Obtener la instancia actual
    invoke GetWindowLong, hWnd, GWL_HINSTANCE
    mov hInstance, eax
    
    ; ---------- Posicionar elementos en el centro horizontal ----------
    ; Calcular el ancho total que ocuparán todos los elementos
    ; Supongamos: [FLAG][espacio10][10][espacio50][CLOCK][espacio10][00:00]

    ; Obtener ancho del texto del contador (FlagCountStr)
    invoke GetTextExtentPoint32, hdc, addr FlagCountStr, 2, addr textWidth

    ; Obtener ancho del texto del timer (TimerStr)
    ; (Podríamos reutilizar textWidth, pero necesitamos ambos para un cálculo preciso)
    invoke GetTextExtentPoint32, hdc, addr TimerStr, 5, addr timerTextWidth
    
    ; Obtener ancho del área cliente
    invoke GetClientRect, hWnd, addr rect
    




    ; Calcular ancho total de cada grupo:
    ; Grupo bandera: iconSize + 10 (espacio) + textWidth
    ; Grupo reloj: iconSize + 10 (espacio) + timerTextWidth
    mov eax, iconSize
    add eax, 10
    add eax, textWidth
    mov ebx, iconSize
    add ebx, 10
    add ebx, timerTextWidth

    ; Espacio entre los dos grupos (150 píxeles)
    mov ecx, 150

    ; Ancho total de todos los elementos: eax (grupo bandera) + ecx (espacio) + ebx (grupo reloj)
    add eax, ecx
    add eax, ebx

    ; Calcular punto de inicio (centro - ancho_total/2)
    mov edx, rect.right
    shr edx, 1          ; Centro de la ventana (rect.right / 2)
    sub edx, eax
    shr edx, 1          ; edx = centro - ancho_total/2 (para centrar todo)

    ; Posición inicial para el icono de bandera
    mov xPos, edx

    ; Cargar el ícono de bandera
    invoke LoadImage, hInstance, IDI_FLAG, IMAGE_ICON, iconSize, iconSize, LR_DEFAULTCOLOR
    mov hFlagIcon, eax
    
    ; Dibujar el ícono de bandera
    invoke DrawIconEx, hdc, xPos, centerY, hFlagIcon, iconSize, iconSize, 0, NULL, DI_NORMAL

    ; Posición para el texto del contador (icono + espacio)
    mov eax, iconSize      ; Cargamos el valor de iconSize en eax
    add xPos, eax          ; Sumamos eax a xPos
    add xPos, 10
    invoke TextOut, hdc, xPos, centerY, addr FlagCountStr, 2

    ; Posición para el icono de reloj (contador + espacio150)
    mov eax, textWidth      ; Cargamos el valor de iconSize en eax
    add xPos, eax          ; Sumamos eax a xPos
    add xPos, 150 - 10  ; Restamos 10 porque ya sumamos 10 después del icono de bandera
    mov xPos, eax       ; Ajustamos para el grupo del reloj

    ; Cargar el ícono de reloj
    invoke LoadImage, hInstance, IDI_CLOCK, IMAGE_ICON, iconSize, iconSize, LR_DEFAULTCOLOR
    mov hClockIcon, eax
    
    ; Dibujar el ícono de reloj (en la misma altura que el de bandera)
    invoke DrawIconEx, hdc, xPos, centerY, hClockIcon, iconSize, iconSize, 0, NULL, DI_NORMAL

    ; Posición para el texto del timer (reloj + espacio)
    mov eax, iconSize      ; Cargamos el valor de iconSize en eax
    add xPos, eax          ; Sumamos eax a xPos
    add xPos, 10
    invoke TextOut, hdc, xPos, centerY, addr TimerStr, 5


    
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