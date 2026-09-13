# Godot Cooperative Vehicle Prototype

## Purpose

This repository is a general experimental workspace. The goal is to use it for short-lived technical prototypes and gameplay experiments. If an experiment proves useful, it can later be promoted into its own dedicated repository.

This document defines the first Godot experiment: a small 3D cooperative sci-fi vehicle prototype focused on **physics-driven piloting** rather than full game production.

## High-level game idea

The eventual game is a colorful, arcade-oriented 3D cooperative survival game. The crew shares a single modular vehicle rather than each player owning a separate vehicle.

Inspirations include:

- **Scrap Mechanic** — constructing interactive machinery from modular parts.
- **Trailmakers** — building vehicles from components and experimenting with their physical behavior.
- **Space Engineers** — mass, thrust, construction, damage and vehicle systems, but the intended game is much lighter, more colorful and more arcade-oriented.
- **Lovers in a Dangerous Spacetime** — multiple players operating different stations of a shared vehicle and needing to coordinate.
- **Minecraft-like crafting** — materials are gathered and transformed into structural and functional parts.

The long-term vehicle should be physically constructed from components such as chassis pieces, panels, engines, vector thrusters, weapons, seats/control stations and other modules. Materials should matter: heavier and stronger materials should change vehicle mass, durability and therefore handling; lighter materials should reduce mass but may be more fragile.

Players should eventually be able to leave the vehicle, walk around as small stylized characters, gather or mine resources, repair or modify the vehicle, change stations and fight enemies. None of that is required for the first prototype.

## Design philosophy

The project should discover gameplay through experimentation rather than attempting to fully design the game in advance.

The first question is deliberately narrow:

> **Is manually piloting a physically simulated shared vehicle with vector thrust fun?**

The prototype should make this answerable as quickly as possible.

## First prototype scope

Build only the minimum needed to test the vehicle physics and controls.

### World

- Simple 3D test world.
- Flat or mostly flat ground plane.
- Camera from above / elevated isometric-like perspective.
- Primitive geometry is sufficient.
- A few visible test landmarks may be added to make movement and scale easier to judge.
- Resource deposits and mining belong to the larger game concept, but are not required for the first physics test unless they are trivial to add after the vehicle works.

### Vehicle

Create a simple rigid vehicle using primitive meshes.

Minimum structure:

- basic chassis/body;
- a conceptual cockpit/control point (visual only is enough initially);
- engine/power source concept;
- **four independently simulated vector thrusters**.

The vehicle is intentionally not a polished craft. Its only purpose is to expose mass, thrust, stability and control behavior clearly.

## Physics requirements

Physics is the core of this experiment.

The vehicle must use a real Godot physics body and respond to forces rather than being translated directly by gameplay code.

At minimum, model and expose:

- total vehicle mass;
- gravity;
- center of mass / torque behavior where practical;
- available engine power;
- requested throttle/input;
- effective thrust per thruster;
- total generated lift/thrust;
- current linear velocity;
- current angular velocity;
- orientation;
- fuel/energy consumption may be represented as a debug value initially, even if the resource itself is unlimited.

The design should make it easy to change mass and thrust values during testing.

## Vector thrusters

The four thrusters are the heart of the prototype.

They should:

- primarily point downward to generate lift;
- have a limited gimbal/vector angle rather than rotating freely in every direction;
- tilt enough to create horizontal acceleration and steering;
- apply force at their actual mounting positions where possible, so asymmetric thrust can naturally create torque;
- expose their current requested and effective thrust independently.

Example behavior:

- To take off, thrust points mostly downward.
- To move forward, the relevant thrust vectors tilt slightly backward.
- To move sideways, vectors tilt appropriately.
- Differential thrust and/or vectoring can contribute to yaw/rotation.

The system should be physically understandable, but it does **not** need to be a perfect aerospace simulation.

## Drone-like stabilization assistance

A completely unaided four-thruster craft would likely be unnecessarily difficult for the intended arcade experience.

The first prototype therefore needs a minimal stabilization system similar in spirit to a quadcopter flight controller.

This is a gameplay assistance layer, not direct movement.

It may:

- compare the vehicle's current orientation with a target orientation;
- calculate corrective torque or differential thrust;
- distribute thrust adjustments across the four thrusters;
- damp excessive angular velocity;
- help maintain a stable hover orientation while still allowing the player to steer.

The stabilizer should preserve the feeling of mass and momentum. It must not simply lock rotation or teleport orientation.

In the future this stabilization functionality could conceptually belong to a craftable gyroscope/flight-controller component. For this prototype the functionality exists directly so we can evaluate the controls.

The strength of the assist should be a tunable parameter and should be visible in debug output.

## Controller input

Prioritize gamepad control.

The intended feeling is that thrust is analog, not binary.

Requirements:

- use analog trigger/stick values;
- throttle intensity should correspond visibly and numerically to generated thrust;
- input mappings should be easy to reconfigure;
- the architecture should support assigning an input axis/trigger to an individual thruster or thruster group for experiments;
- do not hard-code control assumptions deeply into the physics implementation.

The exact final control scheme is intentionally undecided. We should be able to test several mappings quickly.

An example first mapping could use:

- one analog axis for overall lift/throttle;
- stick input for desired horizontal direction / vectoring;
- another stick axis for yaw;
- optional direct per-thruster test bindings for diagnostics.

The important part is that the player can feel the relationship between **input → engine power → thruster output → physical movement**.

## Visual thrust feedback

Each thruster must visibly communicate how much thrust it is producing.

Use a cheap prototype effect such as:

- flame mesh;
- particle stream;
- stretched emissive primitive;
- debug cone/line;
- or a combination.

The visible effect should scale with current effective thrust.

It should also make the current thrust direction obvious, including gimbal/vector angle. The result should let someone watching the screen immediately understand what each thruster is doing.

Polished VFX are not required.

## Runtime physics/debug HUD

The prototype must expose its calculations on screen so we can tune it without guessing.

Show at least:

### Vehicle

- total mass;
- gravity force / estimated hover thrust requirement;
- current speed;
- vertical speed;
- angular velocity;
- current orientation;
- stabilization assist amount;
- total available engine power;
- total requested power;
- total actual thrust.

### Per thruster

For thruster 1–4 show:

- input/throttle request;
- effective thrust;
- maximum thrust;
- thrust percentage;
- current vector/gimbal angle;
- optionally the corrective contribution coming from the stabilizer.

The debug display is part of the prototype, not optional polish.

## Future construction system — context only

Do **not** implement this in the first physics prototype, but architecture choices should avoid blocking it.

The eventual construction system should allow components to attach to each other rather than treating a vehicle as one fixed predefined object.

Examples:

- craft a chassis/core;
- attach structural panels;
- build panels from different materials or layers;
- attach engines and thrusters;
- attach control seats/stations;
- attach weapons such as cannons;
- attach functional modules.

Material combinations should contribute properties such as:

- mass;
- durability;
- damage resistance;
- cost;
- possibly heat/electrical characteristics later.

This should eventually feel like a compact in-game 3D editor / construction mode rather than a conventional inventory-only crafting menu.

## Multiplayer — future context

The final game is cooperative and should support roughly 3–4 crew members sharing the same vehicle.

Possible roles/stations include:

- pilot / propulsion;
- weapons;
- shields;
- engineering / repairs;
- navigation or resource systems.

The crew should have to coordinate rather than one player controlling everything trivially.

Multiplayer is **not required for the first thrust prototype**. First prove the local physics and control feel.

## Code architecture and readability rules

Code readability is a primary project requirement.

The gameplay/business logic should read almost like pseudocode.

### Separate orchestration from implementation

For each meaningful domain, prefer two conceptual layers:

1. **Library/service/calculation layer** — short, focused operations.
2. **Logic/orchestration layer** — expresses the gameplay flow by calling those operations.

Example naming (exact names may be adjusted to follow Godot/GDScript conventions):

- `vehicle_library.gd`
- `vehicle_logic.gd`
- `thruster_library.gd`
- `thruster_logic.gd`
- `stabilizer_library.gd`
- `stabilizer_logic.gd`

### Small functions

Functions should:

- have one clear responsibility;
- be short enough to understand quickly;
- use names based on their purpose;
- avoid hidden side effects when possible;
- use pure calculations where practical.

Examples:

- `calculate_total_mass()`
- `calculate_hover_thrust()`
- `calculate_thruster_force()`
- `calculate_stabilization_correction()`
- `read_pilot_input()`
- `apply_thruster_force()`
- `update_thruster_visual()`
- `update_debug_metrics()`

### Logic classes should be readable as a flow

A high-level function should preferably look conceptually like:

```text
read_pilot_input()
calculate_requested_motion()
calculate_stabilization_correction()
distribute_power_to_thrusters()
apply_thruster_forces()
update_thruster_visuals()
update_debug_metrics()
```

A reader should understand what the game is doing without needing to inspect physics implementation details immediately.

### Keep state explicit

Prefer explicit data/state objects/resources over state hidden throughout many nodes.

Physics calculations should be testable independently where practical.

Avoid giant scripts that mix:

- input;
- physics calculations;
- visual effects;
- UI;
- persistence;
- scene setup.

## Development methodology

This repository is intended to be developed primarily through GitHub, with the local machine acting as an execution/test worker.

### Repository workflow

- Work is committed to GitHub.
- Experimental implementations should normally use a dedicated branch.
- The local machine automatically synchronizes/pulls the relevant repository/branch.
- Avoid treating an independently edited local working copy as the source of truth.
- If an experiment becomes a real project, move/promote it to its own repository later.

### Automated local test loop

Replicate the workflow already being used in the user's other projects:

1. AI/code agent writes and commits changes through GitHub.
2. Local runner/worker synchronizes the repository automatically.
3. It launches the Godot prototype/test.
4. Automated tests run where possible.
5. The local test flow captures useful evidence, especially:
   - screenshots;
   - Godot logs;
   - test output;
   - crashes/errors;
   - relevant runtime metrics.
6. Test artifacts/results are returned or uploaded automatically so the coding agent can inspect them.
7. Iterate based on real execution results rather than assumptions.

The existing local **monigote / AI local-access agent** may be used whenever local execution, file access or test automation is needed.

## Godot knowledge workflow

Before implementing non-trivial Godot functionality:

1. Read the relevant imported Godot skills/guides in this repository.
2. Inspect the relevant existing project code before modifying it.
3. Use official Godot documentation as a reference when a specific API, engine behavior or version detail needs confirmation.
4. Prefer validated implementation over assumptions.

The imported skills are intended to be the primary structured guide because they are organized for practical implementation; official documentation remains the authoritative API reference.

## External Godot skill/tool sources to evaluate

The following repositories were identified for review and selective import into `docs/`:

- https://github.com/jame581/GodotPrompter
- https://github.com/htdt/godogen
- https://github.com/HKUDS/CLI-Anything/tree/main

Do not blindly copy entire repositories. Review them, identify the parts that provide reusable Godot guidance/skills/CLI workflows, preserve attribution/license information, and import only what is useful for this experimental repository.

## Definition of success for prototype 1

Prototype 1 is successful when we can run a scene locally and answer these questions from direct play/testing:

1. Can the craft lift off using four physically simulated thrusters?
2. Does changing analog throttle visibly and physically change thrust?
3. Can limited vectoring move the craft horizontally?
4. Does vehicle mass meaningfully affect the amount of thrust required?
5. Does the stabilization assistance make the craft controllable without eliminating the feeling of physics?
6. Can we clearly see what each individual thruster is doing?
7. Can we inspect the important physics numbers live on screen?
8. Is controlling the vehicle already interesting enough to justify continuing?

Do not expand the prototype until these questions can be tested.

## Immediate next steps

1. Review and selectively import the Godot skills/tools listed above into `docs/`.
2. Create an experimental branch for this prototype.
3. Establish the GitHub → local auto-sync → Godot execution → screenshots/log upload loop.
4. Create the minimal Godot 3D project and test scene.
5. Implement the four-thruster physics model.
6. Implement analog gamepad input.
7. Implement minimal drone-like stabilization assistance.
8. Add per-thruster visual thrust feedback.
9. Add the live physics/debug HUD.
10. Run locally, collect screenshots/logs/metrics and tune from evidence.
