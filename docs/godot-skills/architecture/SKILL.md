---
name: readable-game-logic-architecture
description: Mandatory code-organization rules for General Godot experiments.
---

# Readable game-logic architecture

The user must be able to open the high-level logic file and understand the game flow without first decoding engine details.

## Two-layer rule

For each domain, separate:

1. **Calculation/library/service layer** — small operations, preferably pure.
2. **Logic/orchestration layer** — tells the story of the gameplay by composing those operations.

Example files:

```text
vehicle_library.gd
vehicle_logic.gd
thruster_library.gd
thruster_logic.gd
stabilizer_library.gd
stabilizer_logic.gd
pilot_input_library.gd
```

Exact names can change if a clearer domain name emerges.

## What the orchestration should look like

A physics step should read approximately like this:

```gdscript
func simulate_vehicle_step(state: VehicleState, input: PilotInputState, delta: float) -> void:
    var requested_motion := read_requested_motion(input)
    var stabilization := calculate_stabilization(state, requested_motion)
    var commands := distribute_thruster_commands(state, requested_motion, stabilization)
    apply_thruster_commands(state, commands)
    update_thruster_visuals(state, commands)
    publish_debug_metrics(state, commands)
```

The exact implementation may differ, but this readability is a design requirement.

## Function rules

A function should normally:

- do one thing;
- have a purpose-revealing name;
- accept explicit inputs;
- return an explicit result when it is a calculation;
- avoid unrelated side effects;
- be short enough that its intent is obvious.

Prefer:

```text
calculate_total_mass()
calculate_hover_thrust()
calculate_gimbal_direction()
calculate_stabilization_correction()
distribute_thruster_commands()
apply_thruster_force()
update_thruster_visual()
```

over generic names such as `update_stuff()` or large `_physics_process()` methods.

## Pure core, imperative shell

Keep math/calculations pure where possible. Isolate Godot node mutation/physics calls in a narrow imperative shell.

This gives us:

- easy unit tests;
- easier reasoning about physics;
- easier future multiplayer synchronization;
- easier replacement of input, visuals or persistence;
- readable game logic.

## Explicit state

Use typed state/config objects/resources rather than dozens of unrelated node fields.

Useful conceptual data types:

- `VehicleState`
- `ThrusterState`
- `ThrusterConfig`
- `PilotInputState`
- `StabilizerConfig`
- `PhysicsMetrics`

Avoid a global singleton for ordinary vehicle state.

## Godot callbacks are adapters, not business logic dumps

Callbacks such as `_physics_process`, `_integrate_forces`, `_input`, and signals should translate engine events into calls to the domain logic. Keep them thin.

## Typed GDScript

Use explicit types for parameters, return values, core state and collections. Treat warnings that reveal unsafe or ambiguous code seriously.

## Source basis

Matches the architecture explicitly requested for this project and is consistent with the typed/testable patterns reviewed in GodotPrompter `gdscript-patterns` and `godot-testing`.