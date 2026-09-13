# Game Design — Addon Evaluation Annex

> Companion to `docs/GAME_DESIGN.md`. This file records external Godot addons/demos being evaluated for the long-term cooperative modular-spacecraft game so useful ideas are not lost while the current flight prototype remains narrow.

## Evaluation rule

External assets fall into one of four categories:

- **Runtime dependency** — install/use the addon when its maintained implementation clearly saves substantial work and fits the project architecture.
- **Selective integration** — use only the relevant systems behind a project-owned abstraction; avoid coupling unrelated gameplay domains to the addon.
- **Reference / absorb ideas** — study the source and independently reproduce the useful patterns, especially when language, licensing, scope or architecture does not fit.
- **Editor/development tool** — useful for authoring or import, but not part of the shipped gameplay runtime.

Project-owned game state and domain logic should remain authoritative even when addons provide implementation helpers.

---

## Basic 3D Character Controller

Source: `friendlycosmonaut/basic-3d-character-controller`

Store status during evaluation:

- MIT license.
- Godot 4.6+.
- GDScript.
- Marked unstable by publisher.
- Third-person `CharacterBody3D` controller with controller support, separate third-person camera, animations and simple states for idle/movement, jump and roll.

### Useful role in this game

Good reference/base for **crew characters walking outside the spacecraft, inside stations, inside ships and on conventional surfaces**.

The source is deliberately small and readable. `player.gd` uses `CharacterBody3D`, camera-relative movement, `move_and_slide()`, built-in gravity, animation state transitions and tunable acceleration/deceleration.

### Important limitation

The current implementation assumes a conventional Y-up world:

- horizontal movement is X/Z;
- jump writes `velocity.y`;
- gravity comes from `get_gravity()`;
- turning is performed around global Y.

That is not sufficient by itself for the full game because characters may need:

- radial gravity on asteroids/planetoids;
- arbitrary local gravity inside rotating or oriented environments;
- zero-G EVA outside the spacecraft;
- magnetic boots / surface attachment later.

### Preferred architecture

Use the addon as MIT reference or starter code for a project-owned `CrewMovementController`, then separate movement modes:

```text
CrewMovementController
├── SURFACE
├── LOCAL_GRAVITY
└── EVA_ZERO_G
```

Keep animation/camera logic separate enough that the same crew entity can switch movement mode without changing identity/network state.

### Verdict

**Useful MIT reference and possible starting point, but not sufficient unchanged.**

Use its simple third-person controller/state/camera patterns; extend/rewrite gravity and orientation handling for the game's space environments.

---

## Godot Foundation Dynamic Split Screen Demo

Source: `godotengine/godot-demo-projects/viewport/dynamic_split_screen`

Store status during evaluation:

- Godot Foundation official demo.
- MIT license.
- Godot 4.7+.
- GDScript + Godot shader language.
- Marked unstable on the Asset Store because the store version is a demo/sample.

### Why it matters beyond couch co-op

The most useful architectural pattern is not merely the Voronoi split line. The demo shows how to render **multiple independent Camera3D views into separate SubViewports**, obtain their textures, and compose those textures through UI/shader logic.

That directly supports several concepts in the spacecraft game:

```text
Pilot camera       -> SubViewport A
Gunner camera      -> SubViewport B
Rear/security feed -> SubViewport C
Drone/turret feed  -> SubViewport D

CameraFeedManager
    -> main split-screen
    -> picture-in-picture
    -> cockpit monitor
    -> engineering display
    -> security wall
```

The official demo uses two `SubViewport`s, two cameras and a fullscreen `TextureRect` shader. `camera_controller.gd` feeds both viewport textures and split parameters to that shader.

### Performance rule

Every active 3D SubViewport may require an additional render of the scene. Therefore camera feeds must be budgeted intentionally.

For secondary monitors or security cameras, possible controls include:

- lower viewport resolution;
- reduced update frequency;
- `UPDATE_ONCE`/manual updates where a live 60 Hz feed is unnecessary;
- visibility layers so a feed renders only what it needs;
- disabling feeds when the screen is not visible;
- limiting expensive post-processing on secondary views.

### Preferred architecture

Create a project-owned `CameraFeedManager` / `StationViewManager` rather than embedding the official split-screen demo directly into gameplay code.

The pilot and gunner should each own a logical station camera. Presentation decides whether those feeds appear fullscreen, split, picture-in-picture or on an in-world screen.

### Verdict

**Strong MIT reference; likely reimplement the small pattern rather than add a dependency.**

The SubViewport/camera-texture composition pattern is highly relevant to multi-station spacecraft gameplay.

---

## BallisticSolutions

Source: `neclor/ballistic-solutions`

Store version during evaluation: 6.1.0.

- MIT license.
- Godot 4.5+.
- GDScript and C# interfaces.
- Marked unstable on the Asset Store.
- Computes interception time, target interception position and required initial projectile velocity while accounting for target/projectile acceleration.

### Important distinction

BallisticSolutions is primarily an **aim/interception mathematics library**. It does not replace the projectile gameplay/physics system.

Its normal flow is:

```text
shooter position
+ target position/velocity/acceleration
+ projectile acceleration/speed constraints
        -> solve interception
        -> initial firing velocity
        -> spawn our projectile
```

The projectile itself still needs collision, lifetime, damage, multiplayer ownership and possibly continuous-collision/raycast handling.

### Useful game roles

Very useful for:

- gunner lead indicator;
- aim assist;
- AI turrets;
- point-defense systems;
- enemy firing solutions;
- artillery/cannon prediction;
- displaying predicted impact/intercept points.

For space combat, constant-velocity or constant-acceleration projectiles are an excellent fit. For radial planetary gravity that changes direction significantly over the flight path, the solver may only be an approximation unless the trajectory is short enough to treat acceleration as locally constant.

The library explicitly warns that Godot's default linear damping alters ballistic trajectories; physics settings must match the assumptions used by the solver.

### Preferred projectile architecture

```text
WeaponLogic
    -> BallisticAimSolver
    -> ProjectileSpawner
    -> ProjectileEntity
        ├── movement/physics
        ├── collision
        ├── ShipDamageResolver
        └── network authority
```

For very fast rounds, consider swept ray/shape tests rather than relying solely on discrete rigid-body collision to avoid tunneling.

### Verdict

**Strong candidate as a small MIT math dependency or source library for aiming.**

Do not mistake it for the complete firing/projectile system; combine it with project-owned projectile and damage logic.

---

## Advanced Model Import

Source: `Syvies/godot-plugin-advanced-model-import`

Store version during evaluation: 0.2.1.

- MIT license.
- Godot 4.6+.
- GDScript editor addon.
- Marked unstable.
- Bulk extraction of meshes/materials and bulk reassignment of external materials for imported models.

### Useful role in this game

This is an **authoring/import-pipeline tool**, not a gameplay runtime importer.

Potential use:

- importing purchased/free spaceship interior packs;
- extracting meshes from GLB/FBX packages;
- extracting shared materials;
- replacing inconsistent imported materials with the project's shared PBR material library;
- preparing chassis, engines, props, cargo, stations and interior modules for the runtime construction system.

It could be particularly useful with the project's material strategy because imported packs often duplicate semantically identical materials. The addon can help normalize them to reusable project materials before shipping.

### Non-goal

It does not solve player-supplied model loading at runtime. If runtime import/mod support is ever desired, evaluate that separately.

### Verdict

**Good editor/development utility; low-risk MIT candidate.**

Useful when the project begins importing many external 3D assets, but not needed for the current flight prototype and not a runtime dependency.

---

## GodotNodes+

Source: `Rekiex/godot-nodes-plus`

Store version during evaluation: 1.0.

- MIT license.
- Godot 4.4+.
- Pure GDScript, no external dependencies.
- Composition-first library of reusable nodes.
- Marked unstable on the Asset Store.

The library includes Health, Damage, Shield, Regeneration, Cooldown, Lifespan, StatusEffect, 2D/3D Hitbox/Hurtbox, InteractionArea, Follow/Target, Projectile, Spawner, ObjectPool, StateMachine, Save/Load and utility nodes.

### Why it fits our architecture

The composition-first philosophy maps well to crew, enemies and functional ship modules:

```text
Enemy
├── Health
├── Hurtbox3D
├── StateMachine
├── Target3D
└── StatusEffects

WeaponModule
├── Health
├── Cooldown
└── interaction/repair hooks
```

The current `Health` implementation is intentionally simple: scalar health with signals and `apply_damage()`/`heal()`. That simplicity is useful for normal actors but should not replace our spatial spacecraft hull damage model.

### Where to use it

Good candidates:

- crew/enemy health;
- simple module health after a penetrating hit reaches the module;
- shields;
- cooldowns;
- status effects;
- interaction areas;
- object pooling;
- state-machine helpers;
- generic spawning.

Do **not** make the voxel hull use one `Health` node per voxel. Voxel health/state stays compact in `ShipVoxelGrid` / destruction data.

Also evaluate generic global `class_name` identifiers such as `Health`, `Damage`, `State`, `Save`, etc. for naming collisions with project code before adopting the full addon.

### Overlap with other systems

Its `Projectile3D` is a `CharacterBody3D`-based general projectile. We should not automatically use it for every weapon if our ballistic/network/destruction requirements need a different projectile implementation.

Its JSON Save/Load helpers also should not become the source of truth for complex ship blueprints unless they match the persistence architecture.

### Verdict

**Strong candidate for selective integration.**

Prefer using the small generic components that genuinely remove boilerplate while keeping ship construction, voxel destruction, physics, networking and persistence behind project-owned domain services.

---

## Physics Arsenal

Source: `RockchuckDev/Physics-Arsenal`

Store version during evaluation: 0.2.0-alpha.

- MIT license.
- Godot .NET 4.7 only/tested on 4.7.x.
- C#.
- Marked unstable.
- Physics-based grab/manipulation with independent left/right hands, first-person controller and customizable grabbable behavior.

### Why the interaction concept is valuable

The source shows a useful physical manipulation model rather than teleporting held objects. `PlayerInteraction.cs`:

- raycasts for a grabbable `RigidBody3D`;
- creates a physical grab pivot;
- joins the pivot and object with `Generic6DofJoint3D`;
- applies forces toward the desired hold position;
- applies damping to stabilize motion;
- applies torque and angular damping toward the desired orientation;
- supports independent left/right grabs;
- drops objects when they move outside the valid interaction range.

This is highly relevant to the desired tactile cooperative experience.

### Possible game uses

```text
Crew physical interaction
├── pick up cargo crates
├── carry resources/components
├── move a loose battery/reactor part
├── position an engine near a chassis socket
├── load cargo into the ship
├── manipulate repair parts/tools
├── move debris
└── jointly carry heavy items later
```

Construction can mix two interaction styles:

- **Voxel shell editing** uses precise editor-like tools, not physics grabbing.
- **Large modules/cargo/components** can be physically manipulated and then snap/attach when entering a valid construction socket.

That combination could make building feel tactile without making voxel painting frustrating.

### Main blocker

The project currently targets typed GDScript and the standard Godot workflow. Adopting Physics Arsenal directly would require switching the executable/toolchain to Godot .NET and carrying C# alongside GDScript.

Godot can mix GDScript and C#, but that additional build/export/tooling dependency is not justified solely for this interaction feature at this stage.

Because the addon is MIT and its core interaction algorithm is relatively understandable, the preferred path is to **study and independently implement/port the required grab mechanics in GDScript** behind a project-owned interface.

### Preferred architecture

```text
CrewInteractionController
    -> PhysicsGrabber
        ├── ray/shape selection
        ├── physical hold pivot
        ├── force/damping controller
        ├── torque/damping controller
        └── attach/snap handoff

ShipConstructionLogic
    -> validates socket/module attachment
```

The grabber moves objects; construction logic decides whether an object can actually become part of the spacecraft.

### Verdict

**Excellent interaction reference, but do not add the C#/.NET dependency yet.**

Reimplement the useful MIT physics-grab patterns in GDScript unless the project later has an independent reason to move to Godot .NET.

---

## Combined architecture suggested by this batch

These addons reinforce a clean separation between crew control, camera presentation, aiming, generic gameplay components, physical interaction and ship construction:

```text
CrewEntity
├── CrewMovementController
├── CrewInteractionController
├── Health / statuses
└── CameraRig

StationViewManager / CameraFeedManager
├── pilot feed
├── gunner feed
├── security/rear feed
└── in-world monitor feeds

WeaponSystem
├── BallisticAimSolver
├── ProjectileSpawner
├── ProjectileEntity
└── ShipDamageResolver

ShipConstructionSystem
├── voxel editor
├── module sockets
└── PhysicsGrabber handoff for large modules
```

The player's external-character controller and physical-grab system should remain separate: one controls the crew body, the other manipulates world objects.

## Candidate-map additions — 2026-09-13

| Candidate | Intended role | Current verdict |
|---|---|---|
| Basic 3D Character Controller | Crew third-person movement/camera | Useful MIT base/reference; adapt for radial gravity and zero-G EVA |
| Dynamic Split Screen Demo | Multiple station cameras / split / composed views | Strong official MIT reference; build project-owned CameraFeedManager |
| BallisticSolutions | Moving-target lead/interception math | Strong small MIT candidate for aiming; projectile simulation remains ours |
| Advanced Model Import | Bulk authoring/import cleanup | Editor-only MIT utility; install when asset volume justifies it |
| GodotNodes+ | Generic health/shield/cooldown/status/interaction/pooling/state nodes | Strong candidate for selective integration |
| Physics Arsenal | Physical grab/carry/manipulate interactions | Excellent MIT reference; port needed concepts to GDScript rather than adopting .NET now |
