---
name: vector-thruster-physics
description: Use when implementing the prototype craft, RigidBody3D forces, vector thrusters, mass, torque or stabilization.
---

# Vector-thruster physics

The prototype exists to test **force-driven piloting**. Physics is gameplay, not decoration.

## Non-negotiable rules

- Use `RigidBody3D` for the craft.
- Use continuous force for thrusters, not impulses and not direct transform translation.
- Apply each thruster's force at its mounting point so offset forces can produce torque naturally.
- Never continuously set a RigidBody transform/velocity from ordinary frame code to force the desired result.
- When direct physics-state manipulation is necessary, use `_integrate_forces(state)` and the installed Godot API correctly.
- Use primitive collision shapes for the moving craft.
- Do not scale collision bodies/shapes as a shortcut; configure shape dimensions.

## Core calculation model

Keep these as pure calculations where possible:

```text
weight_force = mass * gravity
hover_thrust_per_thruster ~= weight_force / active_lift_thrusters
requested_thrust = clamp(input * max_thrust + stabilization_correction, 0, max_thrust)
force_vector = thruster_direction * requested_thrust
```

Expose all intermediate values to tests/debug HUD.

Do not hide coefficients in scene scripts. Put tuning values in an explicit configuration/resource/state object.

## Thruster model

Each thruster needs explicit state/configuration:

```text
id
mount_transform / mount_position
base_direction
max_thrust
requested_throttle
effective_thrust
gimbal_limit_degrees
current_gimbal
stabilizer_correction
power_draw
```

The four main thrusters primarily push downward. Their gimbal range is deliberately limited. Horizontal movement comes from tilting the thrust vector, not from a hidden horizontal movement force.

Keep input assignment separate from the thruster itself so a thruster or group can later be wired to different controls.

## Stabilization

The craft needs a drone-like assist because totally manual four-thruster balancing would be frustrating.

The preferred first implementation is a simple attitude controller:

1. Determine desired craft attitude from pilot input.
2. Measure orientation/attitude error.
3. Measure angular velocity.
4. Calculate proportional correction from attitude error.
5. Calculate damping correction from angular velocity.
6. Distribute correction across individual thrusters as differential thrust where practical.
7. Clamp every thruster to valid physical output.

Conceptually:

```text
correction = Kp * attitude_error - Kd * angular_velocity
```

Prefer differential thruster correction because it matches the future idea of a flight-controller/gyro that equalizes motors. A direct corrective torque may exist as a clearly labeled experimental fallback, but it must not silently replace the thruster model.

The assist strength (`Kp`, `Kd`, output limit) must be tunable and visible in debug metrics.

## Physics diagnostics

Every test run should make it possible to see:

- mass;
- gravity/weight force;
- required hover thrust;
- total available thrust;
- total current thrust;
- linear velocity;
- vertical speed;
- angular velocity;
- orientation error;
- stabilizer output;
- per-thruster requested/effective thrust;
- per-thruster gimbal direction;
- per-thruster stabilizer correction.

## Visual force proof

Each thruster must render its actual effective thrust and vector. Use a cheap flame/beam/particle/debug-arrow whose length/intensity follows effective thrust. The effect is diagnostic first and aesthetic second.

A screenshot/video should let us infer which thruster is pushing, in which direction, and approximately how strongly.

## Validate against the installed engine

Godot/Jolt behavior and APIs can change by version. Before coding force-position semantics, integration callbacks, center-of-mass behavior or physics settings, verify the installed version and official API.

## Source basis

Adapted from GodotPrompter `physics-system`, `rigidbody-recipes`, `jolt-differences`, plus the experiment requirements. See `../README.md`.