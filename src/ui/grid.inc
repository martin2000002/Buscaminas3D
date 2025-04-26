; Prototipos de funciones para la cuadrícula del juego
DrawGrids PROTO :DWORD, :DWORD   ; hWnd, hdc
DrawSingleGrid PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD  ; hdc, x, y, gridWidth, gridHeight, gridIndex
HandleGridClick PROTO :DWORD, :DWORD, :DWORD, :DWORD  ; hWnd, x, y, leftClick