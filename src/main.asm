.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib

include include\constants.inc
include include\structures.inc

include src\window\window.inc

.data
; Declaramos los símbolos aquí para ser usados en otros modulos
PUBLIC ClassName
PUBLIC AppName
PUBLIC ErrorMsg
PUBLIC gameState

ClassName       db "BuscaminasClass", 0
AppName         db "Buscaminas 3D", 0
ErrorMsg        db "Error al registrar la clase de ventana!", 0

; Instancia de la estructura de estado del juego
gameState       GameState <>

.data?
hInstance       HINSTANCE ?    ; Instancia de la aplicación
CommandLine     LPSTR ?        ; Línea de comandos

.code
start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    
    invoke GetCommandLine
    mov CommandLine, eax
    
    invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
    invoke ExitProcess, eax

end start