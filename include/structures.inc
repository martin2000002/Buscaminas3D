; Estructura para almacenar el estado del juego
GameState STRUCT
    isRunning       DWORD ?    ; Si el juego está en curso
    timeStarted     DWORD ?    ; Tiempo de inicio (GetTickCount)
    flagsPlaced     DWORD ?    ; Número de banderas colocadas
    cellsRevealed   DWORD ?    ; Número de celdas reveladas
GameState ENDS

; Estructura para una celda del cubo
Cell STRUCT
    hasMine         BYTE ?     ; 1 si tiene mina, 0 si no
    isRevealed      BYTE ?     ; 1 si está revelada, 0 si no
    isFlagged       BYTE ?     ; 1 si tiene bandera, 0 si no
    adjacentMines   BYTE ?     ; Número de minas adyacentes (0-26)
    face            BYTE ?     ; Cara a la que pertenece (0-5)
    x               BYTE ?     ; Coordenada x en la cara (0-3)
    y               BYTE ?     ; Coordenada y en la cara (0-3)
    z               BYTE ?     ; Coordenada z en el cubo (0-3)
Cell ENDS