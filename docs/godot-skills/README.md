# Curated Godot skills for General

This directory is the local, project-oriented knowledge pack to read **before implementing Godot experiments in this repository**.

It is intentionally curated instead of mirroring whole upstream repositories. The goal is to keep the guidance small enough that an agent can actually read the relevant material before touching code.

## Priority order

For a Godot task in this repository:

1. Read the project/experiment document first.
2. Read the relevant `SKILL.md` files in this directory.
3. Inspect the existing implementation before changing it.
4. Verify version-sensitive APIs against the installed Godot version and official Godot documentation.
5. Implement.
6. Run the local proof loop: tests + runtime + logs + screenshots/video where useful.
7. Iterate from observed behavior, not assumptions.

## Prototype defaults

For the cooperative vehicle experiment:

- Godot 4.x, exact installed version must be detected rather than guessed.
- GDScript is the default prototype language unless the experiment explicitly changes that decision.
- Prefer typed GDScript.
- 3D physics should use the engine configured by the installed project; Jolt is preferred for current Godot 4.x 3D projects when supported.
- Real forces/torques drive the craft. Do not fake flight by assigning transforms.
- Pure calculation functions should be separated from orchestration and engine side effects.

## Imported / reviewed sources

### GodotPrompter

Source: https://github.com/jame581/GodotPrompter

Reviewed at commit: `eae755a1f3719076d52f50ab76f21993ebb9682b`

License: MIT, copyright GodotPrompter Contributors.

Most relevant upstream skills reviewed for this prototype:

- `godot-project-setup`
- `physics-system`
- `physics-system/references/rigidbody-recipes.md`
- `physics-system/references/jolt-differences.md`
- `input-handling`
- `input-handling/references/gamepad.md`
- `gdscript-patterns`
- `godot-testing`
- `godot-debugging`
- `camera-system`

Additional upstream skills should be consulted later for HUD/VFX, optimization, multiplayer, components/resources and save/load.

### Godogen

Source: https://github.com/htdt/godogen

Reviewed at commit: `05cebffc8b10c5817e8a3db495b82e7b6004ab84`

License: MIT, copyright 2026 Alex Ermolov.

The upstream Godot guide is C#/.NET-specific, so it is **not** a language mandate for this prototype. We reuse the valuable workflow ideas: detect installed tool versions, keep builds/imports clean, and prove results from the running game with deterministic capture rather than treating a successful compile as proof.

### CLI-Anything / Godot

Source: https://github.com/HKUDS/CLI-Anything

Reviewed at commit: `810c18b0d1ab9b234bc996c9fd999318523a3ef0`

License: Apache-2.0, HKUDS CLI-Anything Team.

Relevant upstream skill: `skills/cli-anything-godot/SKILL.md`.

It exposes agent-friendly Godot CLI operations for project inspection, scenes, GDScript execution/validation, export and engine version detection. It is useful for the GitHub -> local worker -> proof loop, but should be treated as an optional harness: plain Godot CLI remains a valid fallback.

## Local skills

- `project-setup/SKILL.md` — experiment layout, version detection and repository rules.
- `physics-thrusters/SKILL.md` — RigidBody3D, vector thrusters and stabilizer rules.
- `input-gamepad/SKILL.md` — analog controls and reconfigurable thruster bindings.
- `architecture/SKILL.md` — readable library/logic separation requested for this project.
- `testing-proof/SKILL.md` — unit/integration tests and visual runtime proof.
- `debugging/SKILL.md` — logs, metrics and failure-first debugging.
- `cli-automation/SKILL.md` — local execution automation with Godot CLI / CLI-Anything / monigote.

These local skills are adaptations for this repository, based on the upstream material above plus the experiment requirements. They are not intended to replace official Godot API documentation.