# Engine modular AI-first — Documento de diseño

**Versión 0.1** · 4 de octubre de 2026 · **Estado:** ideación (todavía sin código)

---

## 1. Objetivo

Un engine genérico de videojuegos, modular y extensible, optimizado para que una IA lo desarrolle y lo mantenga, pero igual de fácil de seguir para una persona.

Cada feature (animación de personajes 2D y 3D, control y efectos de cámara, efectos especiales, funciones algorítmicas, IA de PNJ, etc.) se resuelve **una sola vez**. Así se deja de reinventar la rueda en cada proyecto y las lecciones aprendidas se acumulan y evolucionan.

### Principios

1. **Contrato primero.** Cada módulo declara qué provee, qué requiere, qué emite y qué consume. Lo demás es detalle interno.
2. **Separación estricta.** Datos, lógica, configuración y vista viven en capas distintas. La lógica nunca conoce la vista.
3. **Headless y determinista.** La simulación corre sin render, con paso fijo y semilla. Esto habilita tests, replays y depuración por IA.
4. **El texto es la fuente de verdad.** Todo es versionable en git y legible por humanos y por IA.
5. **Lo generado es descartable.** Reportes, índices y cachés se pueden borrar y reconstruir.
6. **Cada cosa, una sola vez.** Un solo sistema de animación, uno de cámara, uno de logging, etc.
7. **Divulgación progresiva.** Primero un overview corto; el detalle se abre solo cuando hace falta.

---

## 2. Plataforma y host

### Objetivos de plataforma

- **PC Windows: obligatorio.**
- Después, móviles y web.

### Decisión de fondo

No conviene escribir desde cero el renderer, las físicas, el audio ni el netcode: son años de trabajo y ya existen soluciones maduras. El valor del engine está en los **contratos, la simulación, los validadores y las herramientas**.

### Enfoque propuesto

**Godot como host** (renderer y runtime), con un **core propio y disciplinado**:

- La lógica vive en clases planas, no en `Node`.
- Los nodos son solo vista, finos.
- El estado son datos con esquema; la configuración son archivos de texto.
- Los tests corren headless.
- Las escenas se generan a partir de los datos; la IA maneja Godot por línea de comandos y el editor casi no se usa.

La idea de "AI-first" depende más de cómo se estructura el proyecto que del engine elegido.

### Alternativas evaluadas

| Opción | Ventaja | Costo |
|---|---|---|
| Godot como host | Camino más rápido, muchos plugins, export a móviles | Árbol de nodos que invita al acoplamiento implícito; físicas no deterministas |
| Bevy (Rust) | Code-first, sin editor, muy amigable para IA | API joven y cambiante; suma Rust |
| Engine propio (C++ o Rust) | Control total | Muchísimo trabajo |
| Unity | Ya conocido | Escenas YAML con GUIDs, el menos amigable para IA |
| Web (Three.js, Tauri/Electron, Capacitor) | Una base de código para web, Windows y móviles; fácil de validar | Techo de rendimiento para 3D pesado y límites de memoria en móviles |

### Qué se adopta y qué se escribe

| Área | Decisión |
|---|---|
| Renderer, físicas, audio | Adoptar del host |
| Input | Adoptar, detrás de un contrato propio de acciones |
| Assets y carga dinámica | Usar los del host con un contrato propio encima |
| Multijugador | Adoptar el transporte; la sincronización vive en la simulación determinista propia |
| Efectos | Sistema de cues propio; partículas y shaders del host |
| GUI | Descrita como datos declarativos que un adaptador convierte en controles del host |

### A verificar antes de comprometerse

- Soporte actual de export web cuando el core está en C#.
- Cuánto fricciona la arquitectura dentro de Godot (se resuelve con un spike, ver hoja de ruta).
- Portabilidad: si el core se escribe en un lenguaje del host, cambiar de host implica portar la lógica. Lo que sobrevive intacto son los contratos, los datos y los replays, que permiten comprobar que el port se comporta igual. Si el escape importa, el core podría escribirse en Rust compilado a WASM.

---

## 3. Arquitectura

### Kernel mínimo

El núcleo debe ser muy chico:

- Registro de módulos y resolución de dependencias.
- Bus de eventos y mensajes tipados.
- Scheduler de paso fijo y reloj.
- RNG con semilla.
- Serialización.
- Logger estructurado (inyectado a cada módulo).

Todo lo demás es módulo.

### Capas de cada módulo

| Capa | Contenido |
|---|---|
| `data` | Datos puros y serializables, con esquema |
| `logic` | Lógica pura, sin dependencias de vista ni del host |
| `config` | Ajustes declarativos (tuning) |
| `view` | Adaptadores al host (por ejemplo `godot/`, `web/`) |

Regla dura: **`logic` nunca importa `view`**. Un linter propio lo verifica.

### Cues semánticos

La lógica no ordena "reproducí esta partícula". Emite **cues** (`hit_heavy`, `level_up`). Un mapa en configuración traduce cada cue en animación, efectos, sonido y movimiento de cámara. Se cambia el *feel* sin tocar la lógica.

### Determinismo y headless

- Paso fijo, semilla explícita, sin `Date.now()` ni `Math.random()` en la lógica (se usan el reloj y el RNG del kernel).
- Estado serializable a JSON: la IA puede inspeccionar "qué está pasando" sin capturas.
- Replays: cada bug se convierte en un test de regresión.

---

## 4. Estructura de un módulo

```
modules/camera/
  MODULE.md        # ficha escrita: resumen, intención, contrato, ejemplos, lecciones
  module.yaml      # opcional si el frontmatter de MODULE.md no alcanza
  contract/        # interfaces y esquemas
  data/
  logic/
  config/
  view/
    godot/
    web/
  tests/           # conformidad, ejemplos de la especificación, golden, replays
```

### Ficha `MODULE.md`

Frontmatter YAML para lo estructurado (se valida con un esquema) y Markdown con encabezados fijos para lo narrativo:

```markdown
---
id: camera
icon: camera
version: 1.2.0
source_of_truth: code        # o: intent
requires: [scheduler, cue-bus]
emits: [camera.state]
consumes: [cue.hit, cue.explosion]
---
# Cámara
Resumen: produce el estado de cámara a partir de rigs y modificadores.

## Intención
## Contrato
## Ejemplos
## Lecciones
```

- **Overview:** frontmatter + resumen.
- **Detalle:** cada sección `##` se muestra colapsada en el Studio.
- Sin el Studio, el archivo se lee bien en GitHub o en cualquier visor de Markdown.

### Contratos

- Definidos en esquemas neutrales al lenguaje, con tipos generados para cada lenguaje usado (C#, TS, Python).
- Versionados con semver y changelog.

---

## 5. Dos tipos de módulo

El manifiesto declara quién manda:

```yaml
source_of_truth: intent   # o: code
```

| Tipo | Fuente de verdad | Qué se deriva | Ejemplos de uso |
|---|---|---|---|
| `intent` | Resumen conceptual + especificación (el "prompt") | El código se **genera** | Reglas de negocio, validaciones, condiciones de misiones |
| `code` | El código | El resumen se deriva y se marca como desactualizado si el código cambia | Algoritmos finos: suavizado de cámara, pathfinding |

La sincronización va en **una sola dirección por módulo**. Esto evita el problema histórico de divergencia de la ingeniería de ida y vuelta entre modelos y código.

### Especificación estructurada

Un prompt solo en prosa es ambiguo. La especificación incluye secciones fijas y, sobre todo, **ejemplos**, que se convierten en tests:

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

### Reglas del flujo `intent`

- Al editar la intención, la IA propone un diff del código; corren los validadores; el humano aprueba. Nada cambia en silencio.
- El código generado se commitea y solo se regenera cuando cambia la intención.
- Cada par intención/código guarda un hash. Estados: sincronizado, intención adelantada, código adelantado, conflicto.
- Si alguien edita a mano un archivo generado, el hash lo detecta: el cambio se absorbe en la especificación o se pierde en la próxima regeneración.
- Cuando aparece un bug, lo primero es agregar un **ejemplo nuevo** a la especificación; después se regenera. Así la lección queda en el documento.

### Granularidad

Las tres vistas (símbolo, resumen/intención, código) se aplican a módulos, clases y funciones **públicas del contrato**. Los helpers privados quedan dentro de su padre.

---

## 6. Catálogo inicial de módulos

| Módulo | Idea central |
|---|---|
| Animación | Produce *canales* (valores por nombre en el tiempo) desde grafos de estados o blend trees definidos como datos. Un adaptador los aplica a huesos (3D) o sprites (2D). |
| Cámara | Pila de comportamientos (seguir, encuadrar, apuntar) que produce un `CameraState`, más una cadena de modificadores (shake, punch, zoom). |
| Efectos (VFX/SFX) | Descripciones declarativas interpretadas por el adaptador; disparadas por cues. |
| IA de PNJ | Contrato único `Percepción → Intenciones`, con implementaciones intercambiables (utility, behavior tree, GOAP). Las intenciones son datos. |
| Funciones algorítmicas | Librería de funciones puras (pathfinding, ruido, grillas, easing, FOV) con tests de propiedades. |
| Input | Mapa de acciones propio sobre el input del host. |
| Assets | Contrato de carga y carga dinámica sobre el sistema del host. |
| Multijugador | Sincronización sobre la simulación determinista (rollback o lockstep). |
| UI declarativa | Descripción de interfaz como datos, convertida por el adaptador. |

Los primeros módulos deberían **extraerse de proyectos reales**, no diseñarse en el vacío.

---

## 7. Validación

Dos validadores, cada uno en **dos capas**: primero chequeos mecánicos (deterministas) y después una revisión semántica con IA. La IA sola sería frágil; lo mecánico es la red de seguridad.

| | Mecánico | IA |
|---|---|---|
| **Módulo** | Cumple el contrato, esquemas válidos, sin imports prohibidos, determinismo, presupuesto de performance, documentación presente, linter, tipos, tests | ¿Hace lo que dice la especificación? ¿La API es ergonómica? ¿Los tests cubren las invariantes? ¿El código coincide con la intención? |
| **Integración** | Grafo de dependencias, compatibilidad de versiones, eventos huérfanos, replays y snapshots golden | ¿Las interacciones tienen sentido? ¿Hay acoplamientos ocultos? |

### Linter

Lo valioso son las reglas propias de la arquitectura: `logic` no importa `view`; sin `Date.now()` ni `Math.random()`; sin acceso a módulos no declarados en el manifiesto. A eso se suma el chequeo de tipos.

### Tests

| Tipo | Qué verifica |
|---|---|
| Ejemplos de la especificación | Que el código cumple la intención |
| Contrato | Que respeta puertos y esquemas |
| Propiedades | Invariantes sobre muchas entradas generadas |
| Replays golden | Que el comportamiento no cambió |

- Más útil que el % de cobertura de líneas: **qué reglas de la especificación tienen al menos un test**.
- Si la misma IA escribe código y tests, los tests pueden validar el bug. Mitigación: tests derivados de ejemplos aprobados por el humano, mutation testing en módulos críticos y un agente distinto para escribir los tests.

### Reporte

`engine validate <módulo>` produce un `report.json` con esquema fijo. Lo lee el Studio y también la IA, como retroalimentación estructurada para corregirse sola.

---

## 8. Watcher: `engine watch`

Un proceso local que observa el proyecto y mantiene al día los reportes. Lo automático es el **disparo**; no todo corre siempre.

### Pipeline por niveles

| Nivel | Qué corre | Presupuesto | Cuándo |
|---|---|---|---|
| Instantáneo | Parse (manifiesto, símbolos, imports), hashes, grafo de dependencias | < 100 ms | Cada guardado |
| Rápido | Linter, tipos, tests del módulo | pocos segundos | Cada guardado, en segundo plano |
| Lento | Integración, mutation testing, resumen con IA | minutos | Al commit o en inactividad |

Los niveles lentos corren con baja prioridad y se cancelan si hay un guardado nuevo.

### Principios

- **Solo lectura sobre el código.** Solo escribe en `.engine/`, que ignora para evitar bucles.
- **Todo lo generado es descartable.** Borrar `.engine/` y se reconstruye.
- **Sellos de frescura.** Cada reporte lleva commit, hash del árbol y hora.
- **Incremental por dependencias.** Si cambia A, se revalidan A y sus dependientes.
- **Mismo motor en local y en CI.** `engine watch` y `engine validate --all` producen los mismos reportes.
- **Si falla, no bloquea el desarrollo.** Hay interruptor de pausa.

### Eficiencia

- Caché por hash de entradas (como Nx, Turborepo o Bazel); evaluar apoyarse en uno de ellos, teniendo en cuenta que no entienden C# ni GDScript de forma nativa.
- Invalidación por contrato: si cambia el interior de un módulo pero no su contrato público, los dependientes no se revalidan.
- Proceso residente con todo en memoria.
- Resumen con IA incremental (solo secciones afectadas), con modelo barato y tope de gasto diario.
- Paralelismo entre módulos independientes.

### Evitar el ruido

- Se notifican las **transiciones** (verde → rojo, rojo → verde), no cada corrida.
- La IA recibe un resumen compacto (`engine brief <módulo>`), no logs completos.

### Compilación

Son dos pasos distintos, fuera del watcher:

1. **Generar código desde la intención** (módulos `intent`): lo hace la IA y requiere aprobación.
2. **Compilar y empaquetar para el host:** un build normal.

Al ejecutar, el kernel escribe logs estructurados en `.engine/runs/`; el watcher los ingiere y resume.

### Implementación sugerida

Proceso en TypeScript o Python; chokidar o watchman para observar archivos; tree-sitter para analizar código en varios lenguajes; reportes en JSON y Markdown; WebSocket hacia el Studio.

---

## 9. Studio (interfaz humano-máquina)

Herramienta local (web con React y React Flow, empaquetable con Tauri). Es independiente del host: sirve igual si se cambia de motor.

### Zoom semántico

| Zoom | Qué se ve | Para qué |
|---|---|---|
| Lejos | Ícono + nombre + color de salud | Orientarse en el proyecto |
| Medio | Puertos: qué recibe, qué emite, de qué depende | Entender las conexiones |
| Cerca | Resumen conceptual / especificación | Entender qué hace |
| Muy cerca | Código fuente | Inspeccionar o editar |

El ícono sale del manifiesto (set fijo, como Lucide) y el color indica la categoría.

### Niveles de representación con nodos

Los grafos son la **cara visual de archivos de texto**: editar en el grafo escribe el archivo.

| Nivel | Representación | Fuente de verdad |
|---|---|---|
| Arquitectura | Grafo de módulos y flujo de eventos | Manifiestos |
| Lógica declarativa (behavior trees, máquinas de estado de animación, mapa cue → efecto) | Grafo editable | JSON o YAML con IDs estables; layout en archivo aparte |
| Código | Texto | Archivos de código |

No se usan nodos para escribir lógica de código: escalan mal, los diffs son ilegibles y a la IA le cuesta editarlos.

### Panel de cada módulo

- Símbolo, resumen e intención, código.
- **Historial de git** del módulo (filtrado por ruta), con trailers en los commits (`Module:`, `Layer: intent|code|config`, `Lesson:`), autoría marcada (humano o IA) y diff por capa (primero la especificación, después el código).
- **Última ejecución:** tipo de corrida (validación, replay, sesión en vivo), commit y estado del árbol, semilla, eventos emitidos y consumidos, warnings y errores, tiempos por tick, enlace al replay.
- **Matriz de chequeos con semáforo:** contrato, linter, tipos, tests, sincronización con la intención, última corrida, presupuesto de performance. Cada chequeo indica en qué commit corrió, para detectar resultados viejos.

### Dos archivos de texto por módulo

| Archivo | Contenido | En git |
|---|---|---|
| `MODULE.md` | Lo escrito: resumen, intención, contrato, ejemplos, lecciones | Sí |
| `STATUS.md` / `report.json` | Lo generado: linter, tests, última corrida, sincronización, historial | No (se regenera) |

Un índice generado en la raíz (`MODULES.md`) lista cada módulo con una línea de resumen y su estado, para que la IA navegue sin abrir todo.

---

## 10. Memoria de lecciones

- Cada módulo tiene sección de **Lecciones** y registros de decisiones (ADR) cortos.
- Cada bug resuelto deja un test o un ejemplo nuevo en la especificación.
- Los commits que agregan un ejemplo o test por un bug se destacan como lección aprendida.
- Los contratos tienen semver con changelog.

---

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Abstraer en el vacío | Extraer los primeros módulos de proyectos reales |
| Módulos genéricos sin gracia (mínimo común denominador) | Puntos de extensión explícitos |
| Kernel que crece | Mantenerlo mínimo; todo lo demás es módulo |
| El Studio se come el tiempo del engine | Construirlo por capas (ver hoja de ruta) |
| Generación de código no determinista | Commitear el código generado, regenerar solo al cambiar la intención, mostrar diff, ejemplos y tests como red |
| Tests que validan el bug | Ejemplos aprobados por humano, mutation testing, agente distinto para tests |
| Ruido y lentitud de los chequeos automáticos | Niveles por costo, caché, notificar solo transiciones |
| Sincronización intención/código que diverge | Una dirección por módulo, hashes, aprobación explícita |

---

## 12. Decisiones abiertas

1. Host final (Godot u otro) y lenguaje del core (C#, GDScript o Rust/WASM).
2. Tipo de juegos objetivo (2D, 3D estilizado, tácticos): condiciona el techo de rendimiento necesario.
3. Si se usa un sistema de tareas con caché existente (Nx, Turborepo) o uno propio.
4. Formato definitivo del manifiesto y de la especificación.
5. Estrategia de repositorio: monorepo con historial filtrado por ruta (recomendado para empezar) o repos por módulo.

---

## 13. Hoja de ruta

| Fase | Entregable |
|---|---|
| 0 | Spike: un solo módulo (cámara) en el host elegido, con manifiesto, lógica pura, vista y tests headless, para medir la fricción |
| 1 | Formato de `MODULE.md` y manifiesto; validador mecánico del módulo (`engine validate`) |
| 2 | `engine watch` con el nivel instantáneo y rápido; grafo de módulos de solo lectura generado desde los manifiestos |
| 3 | Overlay de validadores en el grafo; historial de git y última corrida en el panel |
| 4 | Inspector en vivo conectado al juego en ejecución; validador de integración |
| 5 | Edición de grafos declarativos y flujo de módulos `intent` con regeneración asistida |
