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

include src\window\window.inc
include src\ui\header\header.inc
include src\ui\grid\grid.inc
include src\ui\game-over\game-over.inc
include src\game\game.inc

; Variables externas definidas en main.asm
EXTERN ClassName:BYTE
EXTERN AppName:BYTE
EXTERN ErrorMsg:BYTE
EXTERN gameState:GameState

.data
TIMER_ID         EQU 1           ; ID del temporizador
TIMER_INTERVAL   EQU 1000        ; Intervalo en milisegundos (1 segundo)
WM_RESTARTGAME   EQU WM_USER + 2 ; Mensaje personalizado para reiniciar el juego

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
    mov gameState.isGameOver, 0
    
    ; Inicializar la lógica del juego
    invoke InitGame
    
    ret
InitApp endp

; Registrar la clase de ventana
RegisterWinClass proc hInst:HINSTANCE
    LOCAL wc:WNDCLASSEX
    LOCAL hBrush:HBRUSH
    LOCAL hIcon:HICON
    
    ; Limpiar la estructura
    invoke RtlZeroMemory, addr wc, sizeof WNDCLASSEX
    
    ; Crear un pincel con el color de fondo moderno (negro azulado)
    invoke CreateSolidBrush, PRIMARY_COLOR_100
    mov hBrush, eax
    
    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInst
    mov wc.hInstance, eax
    mov ecx, hBrush
    mov wc.hbrBackground, ecx
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset ClassName

    ; Cargar el ícono de la aplicación desde los recursos
    invoke LoadIcon, hInst, IDI_APP
    mov hIcon, eax
    
    ; Asignar el ícono a la clase de ventana
    mov eax, hIcon
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
    LOCAL xPos:DWORD
    LOCAL yPos:DWORD
    LOCAL headerRect:RECT
    
    .if uMsg == WM_CREATE
        ; Iniciar el temporizador para actualizar el reloj cada segundo
        invoke SetTimer, hWnd, TIMER_ID, TIMER_INTERVAL, NULL
        
    .elseif uMsg == WM_TIMER
        ; Si el temporizador ha sido activado (se ha revelado al menos una celda),
        ; actualizar solo el área del encabezado
        mov eax, gameState.timeStarted
        .if eax != 0
            ; Si al menos una celda ha sido revelada, actualizar el header
            mov eax, gameState.cellsRevealed
            .if eax > 0                
                ; Obtener el tamaño de la ventana
                invoke GetClientRect, hWnd, addr headerRect
                
                ; Calcular la altura del header (10% de la altura total)
                mov eax, headerRect.bottom
                mov ebx, 10
                xor edx, edx
                div ebx
                
                ; Establecer el límite inferior del RECT para solo actualizar el header
                mov headerRect.bottom, eax
                
                ; Invalidar solo el área del encabezado
                invoke InvalidateRect, hWnd, addr headerRect, TRUE
            .endif
        .endif
        
    .elseif uMsg == WM_COMMAND
        mov eax, wParam
        .if ax == IDM_EXIT
            invoke DestroyWindow, hWnd
        .endif
        
    .elseif uMsg == WM_LBUTTONDOWN
        ; Obtener posición del clic
        mov eax, lParam
        and eax, 0FFFFh     ; Coordenada X (los 16 bits inferiores)
        mov xPos, eax
        
        mov eax, lParam
        shr eax, 16         ; Coordenada Y (los 16 bits superiores)
        mov yPos, eax
        
        ; Primero, verificar si el clic es en el botón de reinicio
        invoke HandleButtonClick, hWnd, xPos, yPos
        mov ecx, eax
        
        ; Si el clic no fue procesado por el botón, procesarlo para el grid
        .if ecx == 0
            invoke HandleGridClick, hWnd, xPos, yPos, 1
        .endif
        
    .elseif uMsg == WM_RBUTTONDOWN
        ; Obtener posición del clic
        mov eax, lParam
        and eax, 0FFFFh     ; Coordenada X (los 16 bits inferiores)
        mov xPos, eax
        
        mov eax, lParam
        shr eax, 16         ; Coordenada Y (los 16 bits superiores)
        mov yPos, eax
        
        ; Procesar clic derecho
        invoke HandleGridClick, hWnd, xPos, yPos, 0
        
    .elseif uMsg == WM_RESTARTGAME
        ; Reiniciar el juego
        invoke InitGame
        
        ; Invalidar toda la ventana para volver a dibujar
        invoke InvalidateRect, hWnd, NULL, TRUE
        
    .elseif uMsg == WM_GETMINMAXINFO
        ; Obtener puntero a la estructura MINMAXINFO
        mov ebx, lParam
        
        ; Establecer el tamaño mínimo de la ventana
        mov (MINMAXINFO PTR [ebx]).ptMinTrackSize.x, 500
        
        mov (MINMAXINFO PTR [ebx]).ptMinTrackSize.y, 300
        
    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWnd, addr ps
        mov hdc, eax
        
        ; Dibujar el encabezado del juego
        invoke DrawHeader, hWnd, hdc
        
        ; Dibujar las matrices 4x4
        invoke DrawGrids, hWnd, hdc
        
        ; Si el juego ha terminado, mostrar el mensaje de fin de juego y el botón de reinicio
        mov eax, gameState.isGameOver
        .if eax != 0
            invoke DrawGameMessage, hWnd, hdc
            invoke DrawRestartButton, hWnd, hdc
        .endif
        
        invoke EndPaint, hWnd, addr ps
        
    .elseif uMsg == WM_DESTROY
        ; Eliminar el temporizador antes de cerrar
        invoke KillTimer, hWnd, TIMER_ID
        
        invoke PostQuitMessage, 0
        
    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif
    
    xor eax, eax
    ret
WndProc endp

end