# Vector Thruster Prototype

Small Godot **4.7.2** / Jolt experiment for the cooperative vehicle concept.

The only purpose of this branch is to answer whether a four-thruster, physics-driven vehicle is interesting to pilot. There is intentionally no multiplayer, crafting, persistence, auto-sync worker, screenshot upload pipeline, or production UI yet.

## Run

Open `experiments/vector-thruster-prototype/project.godot` in Godot 4.7.2 and run the project (`F6/F5`).

The project explicitly selects:

- Godot 4.7 project features;
- Forward+ rendering on desktop;
- Jolt Physics;
- physics interpolation;
- responsive `canvas_items` + `expand` window scaling.

If you use Godot 4.7's embedded game window and it still appears centered at a fixed resolution when the host window is maximized, choose **Game > Stretch to Fit** (or run the game in a native floating window). The editor's `Fixed Size` embedding mode intentionally overrides normal resize behavior.

## Controls

### Gamepad

- **Right Trigger** — total lift/throttle (analog) while hover hold is off.
- **Left Stick** — vector thrust horizontally.
- **Right Stick X** — yaw by tangential thrust vectoring.
- **A / Cross** — toggle attitude stabilization. Turning it off also disables hover hold.
- **B / Circle** — toggle hover hold. Enabling it captures the current altitude and automatically enables attitude stabilization.
- **Y / Triangle** — reset craft and disable hover hold.

### Keyboard fallback

- **Space** — full lift/throttle while hover hold is off.
- **WASD** — horizontal vectoring.
- **Q / E** — yaw.
- **F** — toggle attitude stabilization.
- **H** — toggle hover hold.
- **R** — reset craft.
- **1 / 2 / 3 / 4** — add a diagnostic boost to one individual thruster.

## Stabilization behavior

The attitude stabilizer is now an anti-flip flight controller rather than a light damping assist:

- normal PD leveling continuously balances pitch and roll with differential thrust;
- at roughly `22°` tilt, a soft guard begins reducing pilot horizontal/yaw authority;
- at roughly `42°` tilt, pilot horizontal authority reaches zero and the flight controller prioritizes recovery;
- correction gains and angular damping increase progressively through that guard zone;
- no transform or rotation lock is used — the controller still works only by changing the four motor outputs.

The limits are deliberately conservative for the prototype and remain exported tuning values on `VehicleLogic`.

## Hover hold

Press **B / H** to capture the current world altitude. While enabled:

- manual lift input is replaced by an automatic hover throttle;
- baseline throttle compensates for gravity and current craft tilt;
- altitude error and vertical speed feed a PD correction;
- attitude stabilization remains enabled;
- the craft can still translate and yaw, subject to the anti-flip envelope.

To descend manually, turn hover hold off and reduce the trigger/throttle yourself.

## What is physically simulated

- `RigidBody3D` chassis with real mass and gravity.
- Four independently computed thrusters.
- Every thruster applies a continuous force at its actual mount offset.
- Limited thrust-vector gimbal.
- Horizontal translation comes from tilted thrust, not direct velocity changes.
- Yaw comes from tangential vectoring at each mount point.
- Stabilization and hover hold only change individual thruster commands; neither sets rotation, position, or velocity directly.
- Reset is the only intentional transform/velocity override and is executed inside `_integrate_forces()`.

## Current tuning values

- vehicle mass: `120 kg`;
- max thrust: `520 N` per thruster (`2080 N` total);
- Earth-like gravity: project default;
- max gimbal: `18°`;
- stabilization mix: `96%`;
- maximum differential stabilization correction: `48%` tuning range per corner calculation;
- soft/hard anti-flip envelope: `22° / 42°`.

At ~9.8 m/s² the craft needs about `1177 N` to hover, or roughly `56-57%` total throttle before vectoring/tilt losses.

## Code layout

- `scripts/input/` — action setup and pilot input state.
- `scripts/stabilizer/` — pure attitude/yaw stabilization and anti-flip calculations.
- `scripts/thrusters/` — pure per-thruster command/distribution calculations.
- `scripts/vehicle/` — orchestration, hover controller and actual RigidBody force application.
- `scripts/visuals/` — larger side-mounted turbine towers plus gimballed nozzle/flame visualization.
- `scripts/audio/` — procedural engine hum whose pitch and level follow total thrust.
- `scripts/camera/` — interpolated elevated follow camera.
- `scripts/ui/` — enlarged live physics/debug HUD.

The vehicle orchestration deliberately reads as a short pipeline: read input → calculate stabilization → resolve hover/safe pilot request → distribute thruster commands → apply forces → capture metrics.
