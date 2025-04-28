; Prototipos de funciones para la cuadrícula del juego
DrawGrids PROTO :DWORD, :DWORD   ; hWnd, hdc
DrawSingleGrid PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD  ; hdc, x, y, gridWidth, gridHeight, gridIndex, hWnd
HandleGridClick PROTO :DWORD, :DWORD, :DWORD, :DWORD  ; hWnd, x, y, leftClick
GetGridGeometry PROTO :DWORD, :DWORD  ; pStartY, pGridSize - Función para obtener la geometría del grid