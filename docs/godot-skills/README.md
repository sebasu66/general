# Godot skills for General

This directory is the repository-local Godot knowledge pack to read **before implementing Godot experiments in this repository**.

It has two layers:

1. **Complete upstream library** — the full GodotPrompter `skills/` tree is vendored at `upstream/GodotPrompter/skills/`, including all 55 top-level skills and all reference files from the pinned upstream commit.
2. **Project-specific adaptations** — the smaller skills directly under `docs/godot-skills/` capture architecture and workflow decisions specific to this repository.

The full upstream copy is intentional: we do not try to predict today which Godot subsystem a future experiment will need. Agents should still read only the skills relevant to the task at hand, but the entire source library remains locally available.

## Priority order

For a Godot task in this repository:

1. Read the project/experiment document first.
2. Read the **complete relevant upstream `SKILL.md` files and their referenced material** under `upstream/GodotPrompter/skills/`.
3. Read the applicable project-specific skills directly under `docs/godot-skills/`.
4. Inspect the existing implementation before changing it.
5. Verify version-sensitive APIs against the exact Godot version and the matching **stable official Godot documentation**, not the unstable `latest` docs.
6. Implement.
7. Run the proof loop appropriate to the maturity of the experiment: runtime, logs, metrics, tests and screenshots/video where useful.
8. Iterate from observed behavior, not assumptions.

## Cooperative vehicle prototype target

The first vector-thruster prototype explicitly targets **Godot 4.7.2 stable**.

Before implementing or changing its core systems, read the relevant 4.7-aware material, especially:

- `upstream/GodotPrompter/skills/godot-project-setup/SKILL.md`
- `upstream/GodotPrompter/skills/3d-essentials/SKILL.md`
- `upstream/GodotPrompter/skills/3d-essentials/references/godot-4.7-additions.md`
- `upstream/GodotPrompter/skills/3d-essentials/references/renderer-comparison.md`
- `upstream/GodotPrompter/skills/physics-system/SKILL.md`
- `upstream/GodotPrompter/skills/physics-system/references/rigidbody-recipes.md`
- `upstream/GodotPrompter/skills/physics-system/references/jolt-differences.md`
- `upstream/GodotPrompter/skills/input-handling/SKILL.md`
- `upstream/GodotPrompter/skills/input-handling/references/gamepad.md`
- `upstream/GodotPrompter/skills/gdscript-patterns/SKILL.md`
- `upstream/GodotPrompter/skills/math-essentials/SKILL.md`
- `upstream/GodotPrompter/skills/camera-system/SKILL.md`
- `upstream/GodotPrompter/skills/camera-system/references/camera3d-patterns.md`
- `upstream/GodotPrompter/skills/scene-organization/SKILL.md`
- `upstream/GodotPrompter/skills/hud-system/SKILL.md`
- `upstream/GodotPrompter/skills/particles-vfx/SKILL.md` when changing thrust VFX
- `upstream/GodotPrompter/skills/godot-debugging/SKILL.md`
- `upstream/GodotPrompter/skills/godot-testing/SKILL.md` when automated testing is introduced

Prototype defaults:

- Godot **4.7.2 stable**.
- Forward+ renderer for the desktop prototype.
- Jolt Physics explicitly selected for reproducibility.
- Typed GDScript is the default prototype language unless explicitly changed.
- Real forces/torques drive the craft. Do not fake flight by assigning transforms or velocities during normal simulation.
- Pure calculations are separated from orchestration and engine side effects.
- The current first milestone is a manually tested playable prototype; the Game Access-style automatic local sync/test/capture pipeline comes later if the flight idea proves worthwhile.

## Vendored GodotPrompter source

Source: https://github.com/jame581/GodotPrompter

Pinned commit: `eae755a1f3719076d52f50ab76f21993ebb9682b`

License: MIT, copyright GodotPrompter Contributors.

Vendor location: `docs/godot-skills/upstream/GodotPrompter/`

The vendor contains the complete upstream `skills/` tree plus its `LICENSE` and `SOURCE.md`. The pinned commit is deliberate so guidance does not silently change underneath an experiment.

## Other reviewed sources

### Godogen

Source: https://github.com/htdt/godogen

Reviewed at commit: `05cebffc8b10c5817e8a3db495b82e7b6004ab84`

License: MIT, copyright 2026 Alex Ermolov.

Its Godot guide is C#/.NET-specific, so it is **not** a language mandate for this prototype. We reuse its useful workflow principle: detect exact tool versions and prove behavior from a running game rather than treating a clean compile/import as proof.

### CLI-Anything / Godot

Source: https://github.com/HKUDS/CLI-Anything

Reviewed at commit: `810c18b0d1ab9b234bc996c9fd999318523a3ef0`

License: Apache-2.0, HKUDS CLI-Anything Team.

Its Godot harness provides agent-friendly inspection, scene, script-validation and export operations. It can be used later for the local worker loop, while plain Godot CLI remains a fallback.

## Project-specific skills

- `project-setup/SKILL.md` — experiment layout, version detection and repository rules.
- `physics-thrusters/SKILL.md` — RigidBody3D, vector thrusters and stabilizer rules.
- `input-gamepad/SKILL.md` — analog controls and reconfigurable thruster bindings.
- `architecture/SKILL.md` — readable library/logic separation requested for this project.
- `testing-proof/SKILL.md` — unit/integration tests and visual runtime proof.
- `debugging/SKILL.md` — logs, metrics and failure-first debugging.
- `cli-automation/SKILL.md` — future local execution automation with Godot CLI / CLI-Anything / monigote.

These project-specific adaptations complement the complete upstream library. Official Godot 4.7 documentation remains authoritative for exact 4.7.2 API behavior.