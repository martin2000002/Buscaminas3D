; Estructura para almacenar el estado del juego
GameState STRUCT
    isRunning       DWORD ?    ; Si el juego está en curso
    timeStarted     DWORD ?    ; Tiempo de inicio (GetTickCount)
    flagsPlaced     DWORD ?    ; Número de banderas colocadas
    cellsRevealed   DWORD ?    ; Número de celdas reveladas
    isGameOver      DWORD ?    ; 2 si por derrota, 1 si por victoria, 0 si no
GameState ENDS

; Estructura para una celda del cubo
Cell STRUCT
    hasMine         BYTE ?     ; 1 si tiene mina, 0 si no
    isRevealed      BYTE ?     ; 1 si está revelada, 0 si no
    isFlagged       BYTE ?     ; 1 si tiene bandera, 0 si no
    adjacentMines   BYTE ?     ; Número de minas adyacentes (0-26)
Cell ENDS

; Estructura para la geometría del grid
GridGeometry STRUCT
    gridSize              DWORD ?   ; Tamaño de cada grid
    cellWidth             DWORD ?   ; Ancho de cada celda
    cellHeight            DWORD ?   ; Alto de cada celda
    startX                DWORD ?   ; Posición X inicial
    startY                DWORD ?   ; Posición Y inicial
    horizontalMarginPixels DWORD ?  ; Margen horizontal en píxeles
    topAreaHeight         DWORD ?   ; Altura del área superior (header)
GridGeometry ENDS