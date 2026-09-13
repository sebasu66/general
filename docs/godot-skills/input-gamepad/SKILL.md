---
name: prototype-gamepad-input
description: Use for analog gamepad input, throttle, gimbal steering and configurable thruster bindings.
---

# Gamepad and analog thrust input

## Input architecture

Gameplay logic consumes **intent**, not hard-coded physical buttons.

Use Godot Input Map actions for normal player controls. Keep the mapping layer separate from physics so the same craft logic can be driven by keyboard, gamepad, tests or later network input.

Continuous analog input belongs in the physics update path. Use action strength/axes/vectors rather than reducing triggers to booleans.

## Prototype input state

Create an explicit input-state object/value bundle such as:

```text
lift: 0..1
move: Vector2
yaw: -1..1
manual_thruster_inputs[4]: 0..1
stabilization_enabled: bool
```

The physics/orchestration layer should receive this state and should not call scattered raw joystick APIs everywhere.

## Suggested first mapping

The final mapping is intentionally undecided. Start with something testable:

- analog trigger/axis -> lift/throttle request;
- left stick -> horizontal desired motion / gimbal target;
- right stick X -> yaw request;
- optional debug actions -> individual thrusters 1-4;
- button -> toggle stabilization for A/B comparison.

Expose input values in the debug HUD.

## Deadzones and controllers

- Prefer Input Map deadzones.
- Use a radial deadzone for raw stick tests if manual reading is required.
- Detect connected joypads instead of assuming device 0 always exists.
- Handle controller hot-plug.
- Do not assume all controllers report identical trigger ranges without testing on the local device.

## Reconfigurable wiring

Do not encode `left_trigger => thruster_1` inside thruster physics.

Represent bindings/configuration separately, e.g.:

```text
ControlBinding
  action_name
  target_thruster_ids
  response_curve
  multiplier
```

That structure is the seed of the later Scrap-Mechanic-like wiring system where a control object can be linked to motors or other machinery.

## Testability

A test should be able to create `PilotInputState` directly without an actual controller and verify:

- zero input produces no pilot thrust request;
- half throttle requests approximately half configured thrust before corrections;
- full throttle clamps to max;
- vector input never exceeds gimbal limit;
- stabilization corrections do not exceed configured authority.

## Source basis

Adapted from GodotPrompter `input-handling` and `input-handling/references/gamepad.md`. See `../README.md`.