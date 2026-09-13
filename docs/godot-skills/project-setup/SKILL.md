---
name: general-godot-project-setup
description: Read before creating or restructuring a Godot experiment in the General repository.
---

# Godot experiment setup

## Before creating files

1. Read the experiment design document.
2. Detect the installed Godot version on the execution machine (`godot --version`, or the configured executable path).
3. Do not hard-code version-sensitive project settings from memory.
4. Check the repository before assuming a scene, addon, input action or directory already exists.
5. Keep each experiment isolated so it can later be promoted to its own repository.

Suggested location:

```text
experiments/<experiment-name>/
  project.godot
  assets/
  scenes/
  scripts/
  resources/
  tests/
  tools/
  test-output/
```

For the first experiment use a descriptive name such as `experiments/vector-thruster-prototype/`.

## Version control

Never commit Godot editor cache/build output as source:

```gitignore
.godot/
.import/
.mono/
bin/
obj/
```

Generated proof artifacts may be committed or uploaded only when they are intentionally part of the automated test result. Put them under a predictable `test-output/` or `artifacts/` path.

## Physics project settings

For a 3D physics experiment:

- verify the active 3D physics engine;
- prefer Jolt on supported current Godot versions;
- use a fixed physics tick rate;
- enable physics interpolation when it improves visual smoothness;
- keep gameplay physics in the physics tick;
- after teleports/initial placement, reset interpolation if required by the installed Godot version.

Do not guess whether a setting name changed between Godot releases: verify it first.

## Scene rule

Scenes should own composition. Runtime behavior belongs in focused scripts/classes. Avoid embedding every system in one root scene script.

For this prototype, favor simple primitive meshes and primitive collision shapes. The purpose is to evaluate flight mechanics, not asset production.

## Source basis

Adapted from GodotPrompter `godot-project-setup`, `physics-system`, and Godogen's Godot engine guide. See `../README.md` for pinned upstream revisions and licenses.