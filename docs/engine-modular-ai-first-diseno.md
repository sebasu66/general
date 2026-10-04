# Engine modular AI-first — Documento de diseño

**Versión 0.2** · 4 de octubre de 2026 · **Estado:** diseño; el primer producto (BGO) ya tiene implementación y el engine se **extrae de él**

### Cambios respecto de la v0.1

- El engine **no se inventa aparte: se extrae de BGO**, el virtual tabletop en Godot que ya implementa gran parte de este diseño.
- Host decidido: **Godot**, con el core en GDScript tipado.
- Primer tipo de juegos: **juego de mesa digital "++"** (mesa 3D lujosa, modelos detallados, raycasting y efectos de cámara).
- Manifiesto de módulo: se adopta la convención de BGO (`component.jsonh` + catálogo de capacidades) en lugar de `module.yaml`.
- Se agrega el principio de **contrato único y sin compatibilidad hacia atrás** mientras sea prototipo.
- La hoja de ruta pasa a ser un **plan de extracción**.

---

## 1. Objetivo

Un engine genérico de videojuegos, modular y extensible, optimizado para que una IA lo desarrolle y lo mantenga, pero igual de fácil de seguir para una persona.

Cada feature (animación de personajes 2D y 3D, control y efectos de cámara, efectos especiales, funciones algorítmicas, IA de PNJ, etc.) se resuelve **una sola vez**. Así se deja de reinventar la rueda en cada proyecto y las lecciones aprendidas se acumulan y evolucionan.

### Principios

1. **Contrato primero.** Cada módulo declara qué provee, qué requiere, qué emite y qué consume. Lo demás es detalle interno.
2. **Estado lógico y vista separados.** Datos, lógica, configuración y vista viven en capas distintas. La lógica nunca conoce la vista.
3. **Headless y determinista.** `Estado + Comando → Estado nuevo + Eventos`. La simulación corre sin render, con semilla. Habilita tests, replays y depuración por IA.
4. **El texto es la fuente de verdad.** Todo es versionable en git y legible por humanos y por IA.
5. **Lo generado es descartable.** Reportes, índices y cachés se pueden borrar y reconstruir.
6. **Cada cosa, una sola vez.** Un solo sistema de animación, uno de cámara, uno de logging, etc.
7. **Divulgación progresiva.** Primero un overview corto; el detalle se abre solo cuando hace falta.
8. **Un solo contrato vigente.** Mientras el engine sea prototipo no hay obligación de compatibilidad hacia atrás: lo obsoleto se borra (git guarda la historia), sin alias ni capas de migración. La compatibilidad empieza cuando un contrato se publica como estable.
9. **Crecer desde juegos concretos.** Las capacidades y validaciones se amplían cuando un juego real las necesita, no por anticipado.

---

## 2. Estrategia: extraer de BGO

BGO es un virtual tabletop en Godot para juegos de mesa por turnos: una sesión lógica compartida que se ve en TV, móviles y escritorio, con clientes web y control por MCP. Su arquitectura ya coincide con la del engine, así que el camino es **extraer** el núcleo genérico, no reescribirlo.

### Equivalencias

| Concepto del engine | Lo que BGO ya tiene |
|---|---|
| Manifiesto de módulo | `component.jsonh` por componente: id estable, tipo, descripción, config tipada, estado, capacidades y verbos |
| Catálogo de capacidades | `capabilities.jsonh`: por capacidad, estado requerido, verbos, eventos y métodos de vista requeridos |
| Protocolo de comandos y eventos | Un único sobre de comando (verbo con puntos, actor, objetivo, argumentos, revisión esperada) que produce eventos en pasado |
| Estado lógico vs vista | `LogicalObjectState` es la única verdad; las escenas de Godot son vista e interacción |
| Ciclo de vida vs flujo vs juego | `SessionState`, `FlowState` y `GameplayState` como conceptos separados |
| Listeners declarativos | Consumen eventos y emiten comandos por el mismo camino, ordenados y acotados |
| Paquete de juego declarativo | `GamePackage` fijado por versión y hash; los juegos no referencian rutas internas |
| Sandbox vs partida | Modo sandbox de autoría separado de la partida con reglas |
| Transporte intercambiable | Abstracción de transporte de sesión (Firebase hoy; otros proveedores a futuro) |
| Interfaz para agentes | Puente de comandos para MCP, API descriptiva por componente y proyección semántica de la web |
| Validador mecánico | `check_structure.py` y un quality gate de CI |
| Panel de estado | `status.json` y dashboard de salud del proyecto |
| Contrato para agentes | `AGENTS.md` con reglas no negociables de arquitectura |
| Perfiles de calidad | Contrato de perfiles de render por plataforma y pipeline de miniaturas con LOD |

### Qué aporta el engine por encima de BGO

1. **Salir del tabletop.** Cámara, animación, efectos, algoritmos e IA de PNJ como módulos independientes y reutilizables.
2. **Validador genérico.** Separar las reglas generales de las específicas de BGO.
3. **Validador de integración.** Eventos huérfanos, grafo de dependencias, detección de caminos que esquivan el protocolo de comandos, replays golden y simulaciones masivas con bots.
4. **Watcher y Studio.** Vista de grafo con zoom semántico, panel por módulo y reportes automáticos.
5. **Intención por módulo.** Resumen conceptual y especificación con ejemplos, además del contrato.

---

## 3. Plataforma y host

### Decisión

**Godot** como host (renderer y runtime), con el core en **GDScript tipado**. Es la decisión de BGO y se mantiene: el "++" pide una mesa 3D lujosa, y el mismo proyecto cubre escritorio, Android, Android TV y web.

- Un core en GDScript evita el problema de export web que puede tener C# en Godot (verificar el estado actual antes de cambiar de lenguaje).
- El lenguaje del core condiciona la portabilidad: un host distinto requeriría portar la lógica. Lo que sobrevive intacto son los contratos, los datos y los replays, que permiten verificar el port.

### Perfiles de render

| Plataforma | Perfil |
|---|---|
| Windows nativo | 3D de alta calidad con LOD y cámara libre |
| Web y móvil | Billboards con cámara de altura y pitch fijos y órbita en yaw |
| Todas | Vista táctica ortográfica (paneo, zoom, cenital) |

La vista puede agrupar objetos para rendimiento y legibilidad; el estado lógico no cambia. Los modelos entran por un pipeline FBX → GLB optimizado con LOD, con validación medible.

### Lo lujoso vive en la capa de vista

- **Raycasting:** el rayo se resuelve a un destino semántico (id de pieza o de casilla) y se envía como comando. La lógica nunca ve coordenadas.
- **Efectos de cámara y animaciones:** salen de un sistema de cues a partir de los eventos.
- **Estado y presentación separados:** el estado salta al resultado final y la vista reproduce los eventos como animaciones.

### Alternativas evaluadas

| Opción | Estado |
|---|---|
| Godot como host | **Elegida** |
| Core en TypeScript con vista web (Three.js, Tauri, Capacitor) | Descartada para este producto: la mesa lujosa pide el renderer de un motor; sigue válida para productos web livianos |
| Bevy (Rust) | Code-first y amigable para IA, pero API joven y suma otro lenguaje |
| Engine propio (C++ o Rust) | Años de trabajo en lo que ya existe |
| Unity | El menos amigable para IA (escenas YAML con GUIDs) |

---

## 4. Arquitectura

### Kernel mínimo

El núcleo debe ser muy chico:

- Registro de módulos (descubre los contratos recursivamente; agregar un módulo no exige editar un `switch` central).
- Catálogo de capacidades y su validación.
- Protocolo de comandos y eventos.
- Estado lógico serializable.
- RNG con semilla y reloj propios.
- Logger estructurado inyectado a cada módulo.

Todo lo demás es módulo.

### Capas

| Capa | Contenido |
|---|---|
| `data` | Estado y definiciones serializables, con esquema |
| `logic` | Lógica pura o casi pura, sin dependencias de vista, red ni proveedor |
| `config` | Ajustes declarativos (tuning) |
| `view` | Escenas y adaptadores del host, que no deciden legalidad ni guardan un segundo estado |

Regla dura: **el dominio no depende de la vista, de Firebase ni de ningún proveedor.** Red y persistencia viven detrás de adaptadores; el render consume el estado y no decide la legalidad.

### Comandos y eventos

- Toda mutación autoritativa entra por el mismo camino: un sobre de comando con verbo estable con puntos (`object.move`, `turn.end`), actor, objetivo opcional, argumentos y revisión esperada.
- Los hechos resultantes son eventos en pasado (`object.moved`, `turn.ended`).
- La UI, la consola, la IA y los listeners declarativos usan el mismo camino. Los listeners nunca escriben estado directo.
- Un verbo por operación semántica: no se duplican operaciones con alias.

### Cues y presentación

La lógica no ordena "reproducí esta partícula". Los eventos se traducen a **cues** (`hit_heavy`, `level_up`) y una configuración mapea cada cue a animación, efectos, sonido y movimiento de cámara. Se cambia el *feel* sin tocar la lógica.

### Determinismo

Paso fijo, semilla explícita y estado serializable a JSON. Cada bug se convierte en un test de regresión y se pueden grabar y reproducir partidas.

### Visibilidad y secretos

La información privada no se protege con capas de render: se filtra por cliente antes de salir del dominio. Vale igual para humanos, espectadores, pantallas, hosts y agentes de IA.

---

## 5. Contratos y manifiesto

### Manifiesto: `component.jsonh`

Se adopta el formato de BGO (JSON estricto). Campos:

```json
{
  "schema": "bgo.component",
  "id": "bgo.piece.miniature",
  "kind": "piece",
  "description": "Miniatura única no apilable.",
  "state": {},
  "scene": "res://src/components/pieces/miniature/miniature.tscn",
  "config": {
    "radius": { "type": "float", "min": 0.1, "max": 2.0, "default": 0.38,
                "description": "Radio de la miniatura.", "agent_visible": true }
  },
  "capabilities": ["movable", "ownable", "placeable"],
  "verbs": {
    "object.move": { "parameters": { "slot_id": { "type": "slot_reference", "required": true } } }
  }
}
```

Para el engine se agregan campos opcionales: `icon`, `version`, `requires`, `emits`, `consumes` y `source_of_truth` (ver sección 6). El namespace `bgo.*` pasa a ser configurable por proyecto.

### Catálogo de capacidades

Cada capacidad declara su ámbito, el estado lógico que exige, los verbos que debe implementar, los eventos que emite y los métodos de vista que necesita. Ejemplo: `movable` exige `location_type` y `location_id`, el verbo `object.move` y el evento `object.moved`. Una capacidad reservada no puede reclamarse hasta que existan sus handlers y tests.

### Ficha narrativa: `MODULE.md`

Complementa al manifiesto (no lo reemplaza). Frontmatter mínimo y encabezados fijos para lo narrativo:

```markdown
---
id: camera
icon: camera
---
# Cámara
Resumen: produce el estado de cámara a partir de rigs y modificadores.

## Intención
## Ejemplos
## Lecciones
```

- **Overview:** frontmatter + resumen. **Detalle:** cada sección `##`, colapsada en el Studio.
- Se lee bien en GitHub o en cualquier visor de Markdown.

### Dos archivos de texto por módulo

| Archivo | Contenido | En git |
|---|---|---|
| Manifiesto + `MODULE.md` | Lo escrito: contrato, resumen, intención, ejemplos, lecciones | Sí |
| `report.json` / `STATUS.md` | Lo generado: linter, tests, última corrida, sincronización | No (se regenera) |

Un índice generado en la raíz lista cada módulo con una línea de resumen y su estado, para que la IA navegue sin abrir todo.

---

## 6. Dos tipos de módulo

```yaml
source_of_truth: intent   # o: code
```

| Tipo | Fuente de verdad | Qué se deriva | Ejemplos de uso |
|---|---|---|---|
| `intent` | Resumen conceptual + especificación (el "prompt") | El código se **genera** | Reglas de juego, validaciones, condiciones de victoria |
| `code` | El código | El resumen se deriva y se marca desactualizado si el código cambia | Algoritmos finos: suavizado de cámara, pathfinding |

La sincronización va en **una sola dirección por módulo**, para evitar la divergencia típica de la ingeniería de ida y vuelta entre modelos y código.

### Especificación estructurada

Un prompt solo en prosa es ambiguo. La especificación incluye secciones fijas y, sobre todo, **ejemplos**, que se convierten en tests. En un juego de mesa, son los ejemplos del reglamento:

```
# calc_damage
Resumen: daño final de un golpe según ataque, defensa y crítico.
Entradas: atk, def, crit (bool)
Reglas:
  1. Daño base = atk − def, con mínimo 1
  2. Si es crítico, se multiplica por 1.5 y se redondea hacia abajo
Ejemplos:
  atk 10, def 4, sin crítico → 6
  atk 3,  def 9, sin crítico → 1
  atk 10, def 4, con crítico → 9
```

### Flujo `intent`

- Al editar la intención, la IA propone un diff del código; corren los validadores; el humano aprueba. Nada cambia en silencio.
- El código generado se commitea y solo se regenera cuando cambia la intención.
- Cada par intención/código guarda un hash: sincronizado, intención adelantada, código adelantado o conflicto.
- Una edición manual de un archivo generado se detecta por hash: se absorbe en la especificación o se pierde en la próxima regeneración.
- Un bug nuevo empieza con un **ejemplo nuevo** en la especificación; después se regenera. La lección queda en el documento.

### Granularidad

Las vistas (símbolo, resumen/intención, código) se aplican a módulos, clases y funciones **públicas del contrato**. Los helpers privados quedan dentro de su padre.

---

## 7. Catálogo de módulos

### Ya existen en BGO (se extraen)

| Módulo | Contenido |
|---|---|
| Estado y protocolo | Estados de sesión, flujo y juego; comandos, eventos y listeners |
| Tablero y espacios | Mesa continua con secciones, grillas, slots y zonas; ocupación lógica autoritativa |
| Componentes de juego | Piezas y miniaturas, cartas, mazos, dados, fichas, contadores, mano, áreas de jugador, contenedores |
| Transporte | Abstracción de transporte de sesión y presencia de jugadores |
| Agentes | Puente de comandos MCP, API descriptiva por componente, consola de comandos |
| Render y cámara | Perfiles de render por plataforma, cámara de runtime, filtro de interacción |
| UI | Menú contextual, barra de acciones, toasts, panel de ajustes, cabecera de sesión |
| Assets | Resolución de assets, validación y pipeline de miniaturas con LOD |

### A crear

| Módulo | Idea central |
|---|---|
| Animación | *Canales* (valores por nombre en el tiempo) desde grafos de estados o blend trees definidos como datos; un adaptador los aplica a huesos o sprites |
| Cámara | Pila de comportamientos (seguir, encuadrar, presets) más una cadena de modificadores (shake, punch, zoom) que produce un estado de cámara |
| Efectos (VFX/SFX) | Descripciones declarativas disparadas por cues |
| Bots y IA de PNJ | Contrato `Percepción → Comandos`, con implementaciones intercambiables (utility, MCTS, behavior tree). Usan los mismos permisos y validación que un humano; también sirven de playtesters automáticos |
| Funciones algorítmicas | Pathfinding, ruido, grillas, easing, FOV: funciones puras con tests de propiedades |
| Input | Mapa de acciones propio sobre el input del host |

---

## 8. Validación

Dos validadores, cada uno en **dos capas**: primero chequeos mecánicos (deterministas) y después una revisión semántica con IA. La IA sola sería frágil; lo mecánico es la red de seguridad.

### Lo que ya existe en BGO

- **Estructura y contratos** (`check_structure.py`): manifiestos válidos, ids únicos y estables, capacidades conocidas, cada capacidad con sus verbos y estado, cada verbo declarado con un handler registrado, escenas existentes, juegos sin referencias a rutas internas, y el core sin dependencias de Firebase ni de red.
- **Quality gate de CI:** formato y lint de GDScript, importación headless de Godot, tests del core, export web validado, E2E en navegador y E2E contra el despliegue de desarrollo.
- **Integridad de contexto y política de código protegido** mediante workflows reutilizables.
- **Evidencia de fallos:** capturas, trazas y estado semántico.

### Matriz objetivo

| | Mecánico | IA |
|---|---|---|
| **Módulo** | Cumple el contrato, esquemas válidos, sin imports prohibidos, determinismo, presupuesto de performance, documentación presente, linter, tipos, tests | ¿Hace lo que dice la especificación? ¿La API es ergonómica? ¿Los tests cubren las invariantes? ¿El código coincide con la intención? |
| **Integración** | Grafo de dependencias, compatibilidad de versiones, eventos huérfanos, caminos que esquivan el protocolo de comandos, replays y snapshots golden, simulaciones masivas con bots | ¿Las interacciones tienen sentido? ¿Hay acoplamientos ocultos? |

### Qué falta

1. **Separar** el validador en una parte genérica (contratos, capacidades, verbos, dependencias prohibidas) y una parte específica del proyecto (rutas, plugins, versiones).
2. **Detección de bypass:** las escrituras que no pasan por el camino canónico de comandos. Es la deuda de transición más importante de BGO y hoy no se detecta automáticamente.
3. **Reporte unificado:** `engine validate <módulo>` produce un `report.json` con esquema fijo, que lee el Studio y también la IA como retroalimentación estructurada.

### Tests

| Tipo | Qué verifica |
|---|---|
| Ejemplos de la especificación | Que el código cumple la intención |
| Contrato | Que respeta puertos, verbos y esquemas |
| Rechazo | Que un comando inválido no muta el estado |
| Convergencia | Que el estado serializado converge entre clientes |
| Propiedades | Invariantes sobre muchas entradas generadas |
| Replays golden | Que el comportamiento no cambió |

- Más útil que el % de cobertura de líneas: **qué reglas de la especificación tienen al menos un test**.
- Si la misma IA escribe código y tests, los tests pueden validar el bug. Mitigación: tests derivados de ejemplos aprobados por el humano, mutation testing en módulos críticos y un agente distinto para escribir los tests.

---

## 9. Watcher: `engine watch`

Un proceso local que observa el proyecto y mantiene al día los reportes. Lo automático es el **disparo**; no todo corre siempre.

| Nivel | Qué corre | Presupuesto | Cuándo |
|---|---|---|---|
| Instantáneo | Parse de manifiestos y símbolos, hashes, grafo de dependencias | < 100 ms | Cada guardado |
| Rápido | Linter, tipos, tests del módulo | pocos segundos | Cada guardado, en segundo plano |
| Lento | Integración, mutation testing, simulaciones, resumen con IA | minutos | Al commit o en inactividad |

### Principios

- **Solo lectura sobre el código.** Solo escribe en `.engine/`, que ignora para evitar bucles.
- **Todo lo generado es descartable.** Borrar `.engine/` y se reconstruye.
- **Sellos de frescura.** Cada reporte lleva commit, hash del árbol y hora.
- **Incremental por dependencias y por contrato.** Si cambia el interior de un módulo pero no su contrato público, sus dependientes no se revalidan.
- **Mismo motor en local y en CI.** `engine watch` y `engine validate --all` producen los mismos reportes.
- **Si falla, no bloquea el desarrollo.** Hay interruptor de pausa.
- **Notifica transiciones** (verde → rojo, rojo → verde), no cada corrida. La IA recibe un resumen compacto (`engine brief <módulo>`), no logs completos.
- Resumen con IA incremental, con modelo barato y tope de gasto diario.
- Caché por hash de entradas. Los sistemas de tareas con caché existentes (Nx, Turborepo, Bazel) no entienden GDScript de forma nativa, así que habría que evaluar cuánto se adaptan.

### Base existente

`status.json` ya es el contrato de salud del proyecto, y el CI le inyecta resultados transitorios sin commitearlos. El watcher lo extiende por módulo.

---

## 10. Studio (interfaz humano-máquina)

Herramienta local, independiente del host. Parte del dashboard de estado que ya existe.

### Zoom semántico

| Zoom | Qué se ve | Para qué |
|---|---|---|
| Lejos | Ícono + nombre + color de salud | Orientarse en el proyecto |
| Medio | Capacidades, verbos y eventos: qué recibe, qué emite, de qué depende | Entender las conexiones |
| Cerca | Resumen conceptual / especificación | Entender qué hace |
| Muy cerca | Código fuente | Inspeccionar o editar |

### Nodos como vista, no como fuente de verdad

| Nivel | Representación | Fuente de verdad |
|---|---|---|
| Arquitectura | Grafo de módulos y flujo de eventos | Manifiestos |
| Lógica declarativa (máquinas de estado, mapa cue → efecto, definiciones de juego) | Grafo editable | Archivos de texto con ids estables; layout aparte |
| Código | Texto | Archivos de código |

Editar en el grafo escribe el archivo. No se usan nodos para escribir lógica de código: escalan mal, los diffs son ilegibles y a la IA le cuesta editarlos.

### Panel de cada módulo

- Símbolo, resumen e intención, código.
- **Historial de git** filtrado por ruta, con trailers en los commits (`Module:`, `Layer: intent|code|config`, `Lesson:`), autoría marcada (humano o IA) y diff por capa (primero la especificación, después el código).
- **Última ejecución:** tipo de corrida (validación, replay, sesión), commit y estado del árbol, semilla, eventos emitidos y consumidos, warnings y errores, tiempos, enlace al replay.
- **Matriz de chequeos con semáforo:** contrato, linter, tipos, tests, sincronización con la intención, última corrida, presupuesto de performance. Cada chequeo indica en qué commit corrió.

---

## 11. Interfaz para agentes

BGO ya define que la web, MCP y la consola son **proyecciones del mismo dominio**, no modelos competidores:

- **MCP** opera sobre conceptos lógicos y comandos validados, nunca sobre nodos de Godot. Un participante de IA tiene los mismos permisos, visibilidad y validación que un humano.
- **API de componentes** de solo lectura (catálogo, objetos, acciones legales, ejecutar comando, suscribirse a eventos), también expuesta como puente de JavaScript en la web, sin evaluación arbitraria de código.
- **Proyección semántica** de la página: estado autorizado, acciones legales, identidad del visor y referencias versionadas a reglas y manual.
- **Privacidad:** el estado legible por agentes pasa por la misma política de visibilidad que el render humano.

El engine estandariza esto como contrato común a todos los módulos.

---

## 12. Memoria de lecciones

- Cada módulo tiene una sección de **Lecciones** y registros de decisiones (ADR) cortos.
- Cada bug resuelto deja un test o un ejemplo nuevo en la especificación.
- Los commits que agregan un ejemplo o test por un bug se destacan como lección aprendida.
- Los contratos tienen versión y registro de cambios desde que se publican como estables.

---

## 13. Riesgos

| Riesgo | Mitigación |
|---|---|
| Generalizar demasiado pronto | Extraer solo lo que BGO ya usa; crecer desde juegos concretos |
| Deuda de transición en BGO (herencia `client_runtime_*`, escrituras directas a repositorios) | Cerrarla antes de extraer; detección automática de bypass |
| Validador acoplado a BGO | Separar parte genérica y parte del proyecto |
| Kernel que crece | Mantenerlo mínimo; todo lo demás es módulo |
| El Studio se come el tiempo del engine | Construirlo por capas (ver plan) |
| Generación de código no determinista | Commitear el código generado, regenerar solo al cambiar la intención, mostrar diff, ejemplos y tests como red |
| Tests que validan el bug | Ejemplos aprobados por humano, mutation testing, agente distinto para tests |
| Ruido y lentitud de los chequeos | Niveles por costo, caché, notificar solo transiciones |
| Trampa con validación en el cliente | Definir quién valida (host o servidor) antes de abrir partidas públicas |

---

## 14. Decisiones abiertas

1. Autoridad de validación: cliente anfitrión con leases de interacción o servidor autoritativo.
2. Transporte en tiempo real definitivo (resultado del spike de transporte).
3. Namespace y nombre del engine frente a `bgo.*`.
4. Cómo expresar módulos fuera del tabletop (cámara, animación) con el mismo manifiesto.
5. Sistema de tareas con caché propio o existente.
6. Cuándo declarar un contrato estable y empezar a versionar.
7. Forma final de la especificación `intent` y su enlace con el manifiesto.

---

## 15. Plan de extracción

| Fase | Entregable |
|---|---|
| E0 | Cerrar la deuda de transición: toda mutación por el camino canónico de comandos. Completar el vertical slice de un abstracto tipo ajedrez/damas con sesión, turnos y resultado |
| E1 | Validador genérico separado del específico de BGO; `report.json` con esquema fijo |
| E2 | Kernel extraído como paquete independiente: registro, capacidades, protocolo de comandos y eventos, logger |
| E3 | `engine watch` con niveles instantáneo y rápido; grafo de módulos de solo lectura generado desde los manifiestos; `status.json` por módulo |
| E4 | Validador de integración, detección de bypass, replays golden y bots como playtesters headless |
| E5 | Primeros módulos fuera del tabletop (cámara y cues, animación), módulos `intent` para reglas y Studio con edición declarativa |
