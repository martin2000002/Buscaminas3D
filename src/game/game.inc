; Prototipos de funciones para la lógica del juego
InitGame PROTO           ; Inicializar el juego
ProcessCellClick PROTO :DWORD, :DWORD, :DWORD, :DWORD  ; gridIndex, cellX, cellY, leftClick
GetCellState PROTO :DWORD, :DWORD, :DWORD, :DWORD      ; gridIndex, cellX, cellY, pCellState
FloodFill3D PROTO :DWORD, :DWORD, :DWORD               ; gridIndex, cellX, cellY
GetElapsedTime PROTO     ; Retorna eax=minutos, edx=segundos