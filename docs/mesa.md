# La mesa — componente base del motor

Estado: borrador de diseño (2026-10-18). Se mueve a su propio repo cuando sea concreto.
Primera implementación: BGO (`C:\DEV\BGO`, `games/*/game.jsonh` → `table`).

## 1. Principios

- **`g` (game) y `m` (match) son cosas distintas.**
  - `g`: definición del juego y sus componentes (mesa, zonas, slots, tableros, piezas, luces). Existe antes de jugar.
  - `m`: la partida en curso. Jugadores, esquema de turnos, reglas, condiciones de victoria y derrota, eventos.
  - En Firebase van en nodos separados, para que cambiar `g` no pise el estado de `m`.
- **Coordenadas:** el centro de la mesa es (0,0). Eje x positivo a la derecha, eje y positivo hacia arriba; negativos en lo opuesto. El tablero usa la misma convención con su propio centro en (0,0). Ejemplo: la celda `(+2,-1)` está dos celdas a la derecha y una abajo del centro del tablero.
- **Un asiento, una zona.** Cada asiento tiene su zona de jugador desde que empieza la partida (idea tomada de boardgame.io: los asientos existen desde `setup`). Conectarse es ocupar un asiento ya existente. Así hay siempre un lugar por defecto donde poner cosas, sueltas o en slots.
- **Todo cambio es un verbo con esquema.** Lo mismo para terminal, MCP y Studio. Cada verbo se valida, cambia el estado, emite un evento y se sincroniza por Firebase a PC, TV y celular, en el momento.

## 2. Propiedades (en `g`)

| Parte | Propiedades |
|---|---|
| Mesa | `mode`: `free` (cualquier cosa en cualquier lado) o `closed` (solo en slots); `size` |
| Superficie | `material` (madera, mármol, metal, blanco…), `color`, `roughness` |
| Ambiente | `preset`, `background_color`, `lights[]` (tipo, posición, intensidad, color) |
| Zona | `id`, `size`, `position`, `visibility`: `public` o `private`, `owner`, `mode` propio opcional |
| Zona de jugador | plantilla que se instancia por asiento; reglas `on_join` |
| Slot | `id`, `accepts[]`, `capacity`, `pose` (posición y rotación), `anchor` |

`anchor` dice a qué está pegado el slot: la mesa, una zona, un tablero (con `cell`) o una carta. Así un slot de mazo puede ir en la celda `(+2,-1)` de un tablero.

## 3. Verbos (árbol `g`, definición)

```
g.table.mode.set("free" | "closed")
g.table.surface.material.set("marble")
g.table.surface.color.set("#ffffff")
g.table.lights.add({type:"point", at:[0,3,0], intensity:2})
g.table.lights.remove(id)
g.table.lights.list()
g.table.zones.add({...})
g.table.zones.resize(id, w, d)
g.table.zones.visibility.set(id, "private")
g.table.slots.add({id:"mazo", accepts:["deck"], anchor:{board:"main", cell:[2,-1]}})
g.table.slots.remove(id)
```

Pedidos de ejemplo a la IA y su traducción:

- "Cambiá a superficie de mármol blanco" → `g.table.surface.material.set("marble")`
- "Poné más luces" → `g.table.lights.add(...)`
- "Poné un slot para mazo en la celda (+2,-1)" → `g.table.slots.add({... anchor:{board:"main", cell:[2,-1]}})`

## 4. Verbos (árbol `m`, partida)

```
m.players.seba.zone.resize(w, d)
m.players.seba.score.add(5)
```

Las reglas de reparto ("cada jugador recibe 4 miniaturas y 5 cartas") se **definen en `g`** como `on_join` y se **ejecutan en `m`** al ocupar un asiento. Sirve también para quien entra tarde, se desconecta o es reemplazado.

## 5. Permisos y semántica

- Los verbos de `g` los ejecuta solo el host. Un cambio de `g` en plena partida afecta a la partida actual, solo si lo hace el host.
- Un verbo inválido devuelve un error legible para la IA, con el campo y los valores aceptados.
- Zonas privadas: se aplican con un filtro único en el servidor (equivalente a `playerView` de boardgame.io), que enmascara lo que no le corresponde ver a cada cliente.
- El azar (barajar) usa un generador con semilla guardada en `m`.

## 6. Decisiones del dueño (2026-10-18)

- **Zona privada:** los demás no ven nada; el contenido es invisible para ellos (por ahora).
- **Mesa cerrada:** soltar fuera de un slot se rechaza. **Mesa abierta:** cerca de un slot se imanta; en otro lado queda suelto, pero igual se ajusta a la grilla para que la mesa sepa su celda.
- **Plantilla de zona de jugador:** la define cada juego. Por defecto es un área delimitada alrededor de la zona pública, como en la realidad. Referencia ante la duda: Tabletop Simulator.
- **Superficie:** texturas PBR de ambientCG.
- **Grilla y escala:** la mesa tiene una grilla con tamaño de celda en cm. Una celda aloja un objeto chico (ficha, dado, miniatura); lo grande (cartas, tableros) ocupa un grupo de celdas.
- **Pivote:** lo que está en una celda o grupo de celdas se centra por su pivote en el centro de esa celda o grupo, salvo que el juego diga otra cosa.
- **Conocimiento en ambos sentidos:** la mesa sabe qué hay en cada celda y slot; cada objeto sabe su celda, su slot y quién lo contiene. Cadena: celda -> slot -> mazo -> cartas, y carta -> mazo -> slot -> celda.

## 7. Preguntas abiertas

1. Tamaño de celda por defecto. Para una carta de póker (63 x 88 mm): con 5 cm ocupa 2 x 2 celdas; con 4 cm, 2 x 3; con 3 cm, 3 x 3. Una ficha, dado o miniatura (hasta unos 3 cm de base) entra en una celda con 3, 4 o 5 cm. Propuesta: dejar 5 cm por defecto y que cada juego fije su `cell_size_cm`.
2. Los objetos declaran su tamaño en cm y la mesa calcula cuántas celdas cubren (redondeando hacia arriba).

## 8. Estado actual en BGO

Ya existe en `games/test001/game.jsonh`: `table` con `areas` y `owner_id`, `slots` con `accepted_kinds` y pose, `placement_mode: free_or_slot`, `surface.material` y `environment`. Falta: el árbol de verbos `g`/`m`, `mode` como `free`/`closed`, luces como lista, `visibility` en zonas, `anchor` en slots, zona de jugador por asiento, `MODULE.md` y tests de la mesa.
