# IA legible, MCP y guardián de cambios

Estado: borrador, ideas dictadas por voz el 2026-10-15. Parte del motor genérico ([diseño](engine-modular-ai-first-diseno.md)). BGO es la primera implementación.

## 1. Página legible para IA ("braille")

- La página web que contiene la instancia de Godot lleva, además de lo visual, una capa paralela de anotaciones invisibles en el HTML que describe qué es cada cosa y de qué trata el juego.
- La IA no interpreta píxeles: lee la escena. Las anotaciones salen de la metadata de cada componente (qué es, qué representa, propiedades), no se escriben a mano.
- Cada instancia de juego tiene una URL única (semilla). Puede ser pública para lectura: leer el HTML no hace daño.
- Acceso de espectador: un parámetro de URL (query param) con un token da lectura sin login completo. Jugar o interactuar exige autenticación.
- La información privada se filtra por cliente antes de salir (ver diseño del motor): un espectador no ve manos ocultas.

## 2. Acceso por MCP a una partida

- Una IA se conecta por MCP a la partida con dos perfiles: **jugador** (mueve piezas con los permisos de su dueño y juega contra una persona) y **host** (arma y arregla la mesa).
- Como host puede montar un escenario: escenografía, miniaturas y piezas en celdas indicadas. Cada pieza tiene metadata propia para que la IA la identifique sin preguntar qué es.
- Puede pedir un screenshot puntual para verificar el montaje, en vez de mirar la imagen todo el tiempo.
- Estado del código en BGO (rama `respaldo`): ya existe `src/mcp/` con una política de acceso con roles host, player, spectator y display. El plugin `godot_ai` ya tiene soporte de screenshot. No encontré la capa de anotaciones en HTML.

## 3. Primer corte vertical: Onitama sin cartas

- Tablero 5x5, tres piezas por jugador, movimiento y turnos. Las cartas quedan para una segunda vuelta.
- Se ve en PC y televisor (mesa 3D) y se controla desde el celular con la vista 2D cenital del [perfil móvil](bgo-perfil-movil.md). Modelos genéricos al principio.
- Lo que BGO ya tiene según el repo: tablero cuadriculado con columnas y filas configurables, slots, manos, miniaturas, área de jugador, definición de juego en `games/*/game.jsonh`, preset de exportación Web, roles de MCP.
- Lo que falta o no está verificado: `games/onitama/game.jsonh`, reglas de movimiento y victoria, la vista 2D de celular, la capa de anotaciones HTML y probar que todo corre. Eso último se verifica abriendo el proyecto en Godot en la PC.

## 4. Guardián de cambios (watcher)

- Problema: que un módulo no se rompa por cambios de una persona o de una IA.
- Qué revisa: que el módulo cumpla su contrato, que sus tests pasen, y que no dependa de módulos que no debe tocar. Además puede proteger archivos concretos que se le indiquen por carpeta.
- Dónde corre: instalado una sola vez fuera de cualquier proyecto, como servicio del sistema con la cuenta de administrador, para que una IA que trabaja con el usuario normal no pueda apagarlo ni cambiar su configuración. Se apunta a carpetas de proyecto (`--path`) y escribe reportes en `.engine/`, ignorada por git.
- Commits: un hook de git mínimo solo consulta al servicio ("¿este commit está bien?") y el commit no se hace si responde que no. La lógica de validación nunca vive en el hook, porque la carpeta `.git/hooks` sí es editable por la IA.
- En GitHub: la misma validación corre como job de CI, como chequeo final (modo validate). El modo watch en vivo solo existe en la máquina local.
- Código: carpeta `watcher/` dentro de `general` mientras sea experimental, y repo propio privado cuando sea estable.
- Pendiente: esqueleto de `watcher/` con kernel mínimo y un módulo de ejemplo para tener algo que observar.
