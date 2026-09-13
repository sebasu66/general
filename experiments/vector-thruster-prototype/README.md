# Vector Thruster Prototype

Small Godot **4.7.2** / Jolt experiment for the cooperative vehicle concept.

The only purpose of this branch is to answer whether a four-thruster, physics-driven vehicle is interesting to pilot. There is intentionally no multiplayer, crafting, persistence, auto-sync worker, screenshot upload pipeline, or production UI yet.

## Run

Open `experiments/vector-thruster-prototype/project.godot` in Godot 4.7.2 and run the project (`F6/F5`).

The project explicitly selects:

- Godot 4.7 project features;
- Forward+ rendering on desktop;
- Jolt Physics;
- physics interpolation.

## Controls

### Gamepad

- **Right Trigger** — total lift/throttle (analog).
- **Left Stick** — vector thrust horizontally.
- **Right Stick X** — yaw by tangential thrust vectoring.
- **A / Cross** — toggle attitude stabilization.
- **Y / Triangle** — reset craft.

### Keyboard fallback

- **Space** — full lift/throttle.
- **WASD** — horizontal vectoring.
- **Q / E** — yaw.
- **F** — toggle attitude stabilization.
- **R** — reset craft.
- **1 / 2 / 3 / 4** — add a diagnostic boost to one individual thruster.

## What is physically simulated

- `RigidBody3D` chassis with real mass and gravity.
- Four independently computed thrusters.
- Every thruster applies a continuous force at its actual mount offset.
- Limited thrust-vector gimbal.
- Horizontal translation comes from tilted thrust, not direct velocity changes.
- Yaw comes from tangential vectoring at each mount point.
- Stabilization changes individual thruster output and yaw vectoring; it does not set rotation directly.
- Reset is the only intentional transform/velocity override and is executed inside `_integrate_forces()`.

## First tuning values

The first pass intentionally has a generous thrust-to-weight ratio so liftoff is easy to find while testing:

- vehicle mass: `120 kg`;
- max thrust: `520 N` per thruster (`2080 N` total);
- Earth-like gravity: project default;
- max gimbal: `18 deg`;
- max stabilization throttle correction: roughly `22%` per thruster.

At ~9.8 m/s² the craft needs about `1177 N` to hover, or roughly `56-57%` total throttle before vectoring losses.

## Code layout

- `scripts/input/` — action setup and pilot input state.
- `scripts/stabilizer/` — pure attitude/yaw stabilization calculations.
- `scripts/thrusters/` — pure per-thruster command/distribution calculations.
- `scripts/vehicle/` — orchestration and actual RigidBody force application.
- `scripts/visuals/` — thruster housing/flame visualization.
- `scripts/camera/` — interpolated elevated follow camera.
- `scripts/ui/` — live physics/debug HUD.

The vehicle orchestration deliberately reads as a short pipeline: read input → calculate stabilization → distribute thruster commands → apply forces → capture metrics.
