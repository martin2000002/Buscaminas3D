; window.asm - Implementación de la ventana para Buscaminas 3D
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

include src\window\window.inc

; Declaramos las variables externas definidas en main.asm
EXTERN ClassName:BYTE
EXTERN AppName:BYTE
EXTERN ErrorMsg:BYTE
EXTERN gameState:GameState

.data
; Color para el área de interfaz superior
UI_BRUSH_COLOR  EQU 00F0F0F0h  ; Color gris claro

; Strings para mostrar
FlagCountStr    db "10", 0
TimerStr        db "00:00", 0

.code

; Función principal de Windows
WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL msg:MSG
    LOCAL hwnd:HWND
    
    ; Inicializar la aplicación
    invoke InitApp, hInst
    
    ; Registrar la clase de ventana
    invoke RegisterWinClass, hInst
    .if eax == 0
        invoke MessageBox, NULL, addr ErrorMsg, addr AppName, MB_ICONERROR
        mov eax, 0
        ret
    .endif
    
    ; Crear la ventana principal
    invoke CreateWindowEx, 0, addr ClassName, addr AppName, \
           WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, \
           WINDOW_WIDTH, WINDOW_HEIGHT, NULL, NULL, hInst, NULL
    mov hwnd, eax
    
    .if hwnd == 0
        invoke MessageBox, NULL, addr ErrorMsg, addr AppName, MB_ICONERROR
        mov eax, 0
        ret
    .endif
    
    ; Mostrar la ventana de forma explícita
    invoke ShowWindow, hwnd, SW_SHOW
    invoke UpdateWindow, hwnd
    
    ; Bucle de mensajes
    .while TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw
    
    mov eax, msg.wParam
    ret
WinMain endp

; Inicializar la aplicación
InitApp proc hInst:HINSTANCE
    ; Inicializar el estado del juego
    mov gameState.isRunning, 0
    mov gameState.timeStarted, 0
    mov gameState.flagsPlaced, 0
    mov gameState.cellsRevealed, 0
    
    ret
InitApp endp

; Registrar la clase de ventana
RegisterWinClass proc hInst:HINSTANCE
    LOCAL wc:WNDCLASSEX
    
    ; Limpiar la estructura
    invoke RtlZeroMemory, addr wc, sizeof WNDCLASSEX
    
    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInst
    mov wc.hInstance, eax
    mov wc.hbrBackground, COLOR_WINDOW+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset ClassName
    
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    
    invoke RegisterClassEx, addr wc
    ret
RegisterWinClass endp

; Procedimiento de ventana
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL ps:PAINTSTRUCT
    LOCAL hdc:HDC
    LOCAL rect:RECT
    LOCAL hBrush:HBRUSH
    LOCAL hFlagIcon:HICON
    LOCAL hClockIcon:HICON
    LOCAL hInstance:HINSTANCE
    LOCAL topAreaHeight:DWORD
    LOCAL centerY:DWORD
    LOCAL textWidth:DWORD
    LOCAL textHeight:DWORD
    LOCAL xPos:DWORD
    LOCAL iconSize:DWORD
    
    .if uMsg == WM_CREATE
        ; Inicializaciones adicionales al crear la ventana
        
    .elseif uMsg == WM_COMMAND
        mov eax, wParam
        .if ax == IDM_EXIT
            invoke DestroyWindow, hWnd
        .endif
        
    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWnd, addr ps
        mov hdc, eax
        
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
        
        ; Calcular posición vertical centrada para los íconos y texto
        mov eax, topAreaHeight
        mov ebx, 2
        xor edx, edx
        div ebx
        mov centerY, eax
        
        ; Establecer el tamaño del ícono (16x16 píxeles)
        mov iconSize, 16
        
        ; Obtener la instancia actual
        invoke GetWindowLong, hWnd, GWL_HINSTANCE
        mov hInstance, eax
        
        ; ---------- Mostrar ícono de bandera y contador ----------
        ; Cargar el ícono de bandera
        invoke LoadImage, hInstance, IDI_FLAG, IMAGE_ICON, iconSize, iconSize, LR_DEFAULTCOLOR
        mov hFlagIcon, eax
        
        ; Calcular posición vertical centrada para el ícono
        mov eax, centerY
        sub eax, 8  ; La mitad del tamaño del ícono (16/2)
        
        ; Dibujar el ícono de bandera
        invoke DrawIconEx, hdc, 20, eax, hFlagIcon, iconSize, iconSize, 0, NULL, DI_NORMAL
        
        ; Calcular el tamaño del texto para centrar verticalmente
        invoke GetTextExtentPoint32, hdc, addr FlagCountStr, 2, addr textWidth
        mov textHeight, eax  ; La altura del texto se almacena en eax
        
        ; Calcular posición vertical centrada para el texto
        mov eax, centerY
        sub eax, textHeight
        shr eax, 1  ; Dividir por 2
        
        ; Dibujar el contador de banderas
        invoke TextOut, hdc, 46, eax, addr FlagCountStr, 2
        
        ; ---------- Mostrar ícono de reloj y timer ----------
        ; Cargar el ícono de reloj
        invoke LoadImage, hInstance, IDI_CLOCK, IMAGE_ICON, iconSize, iconSize, LR_DEFAULTCOLOR
        mov hClockIcon, eax
        
        ; Obtener ancho del área cliente
        invoke GetClientRect, hWnd, addr rect
        mov eax, rect.right
        mov xPos, eax
        shr xPos, 1  ; Dividir por 2 para obtener el centro
        sub xPos, 50 ; Ajustar para que quede centrado el conjunto
        
        ; Calcular posición vertical centrada para el ícono
        mov eax, centerY
        sub eax, 8  ; La mitad del tamaño del ícono (16/2)
        
        ; Dibujar el ícono de reloj
        invoke DrawIconEx, hdc, xPos, eax, hClockIcon, iconSize, iconSize, 0, NULL, DI_NORMAL
        
        ; Calcular el tamaño del texto para centrar verticalmente
        invoke GetTextExtentPoint32, hdc, addr TimerStr, 5, addr textWidth
        mov textHeight, eax  ; La altura del texto se almacena en eax
        
        ; Calcular posición vertical centrada para el texto
        mov eax, centerY
        sub eax, textHeight
        shr eax, 1  ; Dividir por 2
        
        ; Dibujar el timer
        add xPos, 26
        invoke TextOut, hdc, xPos, eax, addr TimerStr, 5
        
        ; Ya no necesitamos mostrar el texto de confirmación
        
        invoke EndPaint, hWnd, addr ps
        
    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage, 0
        
    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif
    
    xor eax, eax
    ret
WndProc endp

end