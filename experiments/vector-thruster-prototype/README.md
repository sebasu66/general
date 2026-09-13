# Vector Thruster Prototype

Small Godot **4.7.2** / Jolt experiment for the cooperative vehicle concept.

The current prototype tests both the flight feel and the first pass of a **physical ship-component architecture**: pilot seat, central computer, motor, renewable power source/battery and four vector nozzles are separate objects that communicate through signals routed by the ship computer.

## Run

Open `experiments/vector-thruster-prototype/project.godot` in Godot 4.7.2 and run the project (`F6/F5`).

The project explicitly selects Forward+, Jolt Physics, physics interpolation and responsive `canvas_items` + `expand` window scaling.

## Controls

### Gamepad

- **Right Trigger** — manual lift/throttle while hover hold is off.
- **Left Stick** — vector thrust horizontally.
- **Right Stick X** — yaw.
- **A / Cross** — attitude stabilizer.
- **B / Circle** — hover hold.
- **X / Square** — ship computer terminal.
- **Y / Triangle** — reset craft.

### Keyboard

- **Space** — manual lift.
- **WASD** — horizontal vectoring.
- **Q / E** — yaw.
- **F** — attitude stabilizer.
- **H** — hover hold.
- **T** — ship computer terminal.
- **R** — reset craft.
- **1 / 2 / 3 / 4** — diagnostic boost to an individual nozzle.

## Component architecture

The vehicle is no longer treated as one monolithic script. Each gameplay part owns its state, behavior and 3D representation.

### Pilot seat

Files:

- `scripts/pilot/pilot_seat_library.gd`
- `scripts/pilot/pilot_seat_logic.gd`

It samples physical controls and emits typed control/mode events. It does not directly manipulate a motor or nozzle.

### Ship computer

Files:

- `scripts/computer/ship_computer_library.gd`
- `scripts/computer/ship_computer_logic.gd`
- `scripts/computer/ship_computer_ui.gd`

The ship computer is the connection hub. It wires the event listeners/dispatchers between the pilot seat, nozzles, motor and power source. Press **T / X** to open the in-game terminal. The current terminal is read-only and shows an ASCII-style topology plus live power, battery and nozzle data. Later this becomes the place where the player can alter connections and properties.

The Godot console also logs component startup, connection wiring and rate-limited event trigger/listener activity so the routing can be inspected without flooding one line per physics frame.

### Main motor

Files:

- `scripts/engine/engine_library.gd`
- `scripts/engine/engine_logic.gd`
- `scripts/engine/engine_ui.gd`

The motor exposes a fuel/power request interface rather than owning an unlimited energy source. Requested output becomes an energy request; granted energy determines actual motor output. Its procedural engine sound follows the actual output rather than just the trigger position.

### Renewable power source + battery

Files:

- `scripts/power/power_source_library.gd`
- `scripts/power/power_source_logic.gd`
- `scripts/power/power_source_ui.gd`

The starter power source continuously collects solar energy into a battery. Current tuning is deliberately arranged so normal level hover is close to energy-neutral:

- battery capacity: about `1200` energy units;
- solar generation: about `58 u/s` in full light;
- motor maximum draw: `100 u/s` at full output;
- level hover: about `56-57%` motor output, therefore roughly `56-57 u/s` consumption.

This means sitting still with the motor off recharges the battery quickly, normal hover approximately maintains charge, and sustained hard thrust drains the battery. If stored charge reaches zero, the motor can only use the energy arriving from the solar source at that moment.

The power UI shows battery charge, positive solar input, negative motor consumption and net flow.

### Vector nozzles

Files:

- `scripts/thrusters/thruster_library.gd`
- `scripts/thrusters/thruster_logic.gd`
- `scripts/visuals/thruster_visual.gd`

Each nozzle owns its maximum thrust/gimbal properties and listens for routed nozzle commands. It exposes throttle and vector-direction methods. The blue exhaust is now translucent, emits blue local light and has a small amount of vapor/smoke rather than a heavy opaque plume.

## Event flow

The live path is deliberately close to a physical/electrical ship:

```text
Pilot Seat
    │ control events
    ▼
Ship Computer
    │
    ├──────────────► Vector Nozzles
    │                    ▲
    │                    │ available motor output
    ▼                    │
Main Motor ──────────────┘
    │ energy request
    ▼
Ship Computer
    │
    ▼
Solar Sensor + Battery
    │ energy grant
    └──────────────► Ship Computer ───────────────► Main Motor
```

The `RigidBody3D` still owns the final force application because Jolt requires forces to be applied to the physical body, but the requested control, energy availability and nozzle state are all produced by the component system first.

## Flight assistance

The attitude controller still uses real differential nozzle thrust. At roughly `22°` the anti-flip guard starts reducing dangerous pilot authority, and at roughly `42°` it prioritizes returning upright. Hover hold captures the current altitude and automatically balances thrust against gravity and vertical error.

No normal flight mode rotates or translates the vehicle by directly changing its transform. Reset remains the intentional exception inside `_integrate_forces()`.

## World

The old 80×80 flat box has been replaced by a seeded procedural terrain:

- roughly `260×260 m`;
- height variation generated with layered `FastNoiseLite` noise;
- a gently flattened spawn region;
- multiple ground color/material zones;
- dozens of seeded rock/resource deposits with different metallic/stone appearances;
- softer overhead sunlight with soft shadows;
- lower ambient fill, SSAO/SSIL and light volumetric fog so valleys and terrain pockets remain visibly darker.

The seed is deterministic so the same prototype world is reproduced on every run.

## UI

The previous wall of abstract physics/debug numbers is hidden from the normal frontend. The normal HUD now shows only useful flight state, while dedicated component UIs show motor power and battery/energy flow. Detailed event diagnostics remain in the Godot console and the ship-computer terminal.

## Current physical tuning

- vehicle mass: `120 kg`;
- four nozzles at `520 N` max each (`2080 N` total);
- max nozzle gimbal: `18°`;
- soft/hard anti-flip envelope: `22° / 42°`;
- Earth-like gravity.

At ~9.8 m/s² the craft needs roughly `1177 N` to hover, around `56-57%` aggregate throttle before vectoring/tilt losses.
