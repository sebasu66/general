---
name: godot-testing-and-proof
description: Use whenever implementing or changing a Godot experiment; requires automated checks plus runtime evidence.
---

# Tests and runtime proof

A clean parse/build is necessary but is **not proof that the game works**.

The required loop is:

```text
GitHub change
  -> local auto-sync
  -> headless validation/tests
  -> launch real prototype
  -> exercise deterministic scenario
  -> collect logs + metrics + screenshots/video
  -> return artifacts
  -> inspect evidence
  -> iterate
```

The local monigote/worker may drive this loop.

## Testing strategy

For a GDScript prototype, GUT is a sensible default if a test framework is needed. Do not install an addon blindly: check current project state and the current framework release first.

Prioritize tests for pure functions:

- mass aggregation;
- hover-force calculation;
- throttle -> thrust mapping;
- gimbal clamping;
- stabilizer proportional/damping calculations;
- per-thruster power distribution;
- input mapping;
- metric formatting/state.

Physics integration tests should test behavior with tolerances rather than exact floating-point equality.

## Minimum automated gates

Before reporting an implementation as working:

1. Godot project imports/opens without parse errors.
2. Script validation/headless startup exits successfully.
3. Unit tests pass.
4. A deterministic physics scenario runs for a bounded time.
5. The test saves machine-readable metrics/logs.
6. At least one screenshot proves the visual state when visuals changed.
7. For movement/flight behavior, a short video or multiple time-separated screenshots are preferable to a single still.

## Deterministic scenario for the first prototype

Automate a short flight sequence, for example:

```text
0-1s: no throttle; craft rests/falls onto test pad
1-3s: ramp lift toward hover
3-5s: increase lift and leave ground
5-7s: vector forward
7-9s: release horizontal command; stabilizer settles craft
9-11s: reduce thrust and descend
```

Capture per-frame or sampled telemetry. This lets us compare commits numerically and visually.

## Runtime artifacts

Suggested structure:

```text
test-output/<run-id>/
  result.json
  godot.log
  screenshot-01.png
  screenshot-02.png
  video.mp4          # when available/useful
```

`result.json` should include installed Godot version, commit SHA, pass/fail, maximum altitude/speed/tilt, sampled thruster values and any assertion failures.

## Capture ideas from Godogen

Godogen's reviewed guide uses Godot's movie writer with fixed FPS for deterministic proof, followed by ffmpeg to encode frames. Reuse the principle, but adapt commands to the installed Godot build/OS rather than copying Linux commands blindly.

A fixed-FPS scripted scenario is preferred over manually pressing buttons for regression proof.

## What not to test

Do not waste tests proving Godot's own basic engine methods work. Test our calculations, contracts and observed gameplay behavior.

## Source basis

Adapted from GodotPrompter `godot-testing` / `godot-debugging` and Godogen's proof-over-claims workflow. See `../README.md`.