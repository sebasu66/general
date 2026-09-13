---
name: godot-debugging-general
description: Use when a Godot experiment fails, behaves strangely, or needs observable runtime diagnostics.
---

# Debugging rules

## Evidence before guesses

When something fails:

1. reproduce it;
2. capture the exact Godot version and command used;
3. preserve stdout/stderr and Godot errors;
4. inspect the running scene/state where possible;
5. reduce to the subsystem involved;
6. fix the cause;
7. add a regression test or deterministic scenario.

Do not make speculative code changes before reading the error/log and relevant code.

## Logging

Use severity intentionally:

- ordinary structured metrics for expected diagnostic information;
- debug-only output for noisy frame-level values;
- warnings for recoverable suspicious states;
- errors for violated assumptions/invalid states;
- stderr/terminal-visible logging when the local worker needs to collect it.

For the vehicle prototype, avoid flooding logs every physics frame. Sample telemetry or write structured output at a controlled interval.

## Required live diagnostics

The prototype HUD should mirror the important internal state:

- gamepad/raw intent;
- mass;
- total/required lift;
- orientation and angular velocity;
- stabilizer correction;
- each thruster's throttle, thrust and gimbal.

If the craft behaves incorrectly, the visual debug values should help answer **why**.

## Physics-specific failure checks

When flight behaves oddly, check in this order:

1. correct mass/gravity units;
2. thrust sign/direction;
3. coordinate-space conversion;
4. force application point;
5. gimbal clamp;
6. per-thruster saturation/clamping;
7. center of mass;
8. stabilizer sign;
9. `Kp`/`Kd` magnitude;
10. physics timestep/interpolation;
11. active physics engine/version-specific behavior.

A wrong sign or coordinate space can look like a tuning problem; verify math before tuning gains.

## Runtime inspection

When manual inspection is needed, use Godot's remote scene tree/inspector, debugger monitors, breakpoints and profiler. Automated runs should still emit enough information that an agent can diagnose without relying exclusively on editor UI.

## Source basis

Adapted from GodotPrompter `godot-debugging` and `physics-system`. See `../README.md`.