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
include src\ui\header.inc      ; Incluir el header.inc
include src\ui\grid.inc        ; Incluir el nuevo grid.inc

; Declaramos las variables externas definidas en main.asm
EXTERN ClassName:BYTE
EXTERN AppName:BYTE
EXTERN ErrorMsg:BYTE
EXTERN gameState:GameState

.data
; Variables locales

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
        
        ; Dibujar el encabezado del juego
        invoke DrawHeader, hWnd, hdc
        
        ; Dibujar las matrices 4x4
        invoke DrawGrids, hWnd, hdc
        
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