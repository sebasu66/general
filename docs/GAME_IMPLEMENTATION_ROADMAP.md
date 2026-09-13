# Game Implementation Roadmap — Voxel-First

> Companion to `docs/GAME_DESIGN.md` and `docs/GAME_DESIGN_ADDON_EVALUATIONS.md`.
> This file defines the preferred implementation order so the game grows from a stable technical foundation instead of integrating unrelated subsystems too early.

## Core implementation decision

The next major architectural step should be a **project-owned voxel substrate** that can be reused by the world, spacecraft hulls, destructible structures and selected enemies.

The target is explicitly **not Minecraft-style large cubes**. Voxels should be small enough that groups of them read as organic or manufactured continuous forms at normal gameplay distance.

The important distinction is between **authoritative voxel data** and **render representation**.

```text
Voxel data remains individual and editable at all times
                     |
                     v
             chunk mesh compiler
                     |
                     v
      merged / exposed-face render geometry
```

An intact object should therefore render as a small number of merged chunk meshes rather than thousands of cubes or nodes.

When an area is damaged, the voxel data does not need to be recreated: it was never lost. The affected chunk is rebuilt from the changed voxel state, and only debris or detached pieces that need independent physics become separate objects.

Conceptually:

```text
INTACT
individual voxel data
        -> merged chunk mesh
        -> compiled collision

IMPACT
        -> modify voxel health/state
        -> remove/damage voxels
        -> rebuild dirty chunk
        -> expose internal faces
        -> optionally spawn local debris

MAJOR FRACTURE
        -> connectivity / structural test
        -> detached meaningful region
        -> new physical entity
```

This gives the desired feeling that voxels visually "merge" while intact and "recover their individuality" under damage without paying the runtime cost of one Godot node or one rigid body per voxel.

## Scope of the voxel foundation

The voxel system should be generic enough to support several contexts while allowing each context to use different physics/streaming policies.

### Static / world voxel objects

Examples:

- asteroids;
- small moons / planetoids;
- mineable rocks;
- destructible terrain sections;
- some station or ruin structures.

These can use world/static collision and spatial streaming.

### Moving voxel objects

Examples:

- player spacecraft hull;
- enemy spacecraft hulls;
- detached ship sections;
- selected destructible machinery.

These remain children of a project-owned authoritative `RigidBody3D` or equivalent gameplay body. The voxel subsystem generates visuals, damage state and collision data but does not replace the high-level vehicle physics architecture.

### Things that should *not* automatically become voxels

Do not force every asset into the voxel representation.

Keep conventional meshes/nodes where they are a better fit:

- chassis/frame skeletons;
- engines and complex functional modules;
- characters;
- weapons and articulated machinery;
- furniture/interior props;
- many enemies;
- UI and camera systems.

The voxel layer is primarily for destructible material volume, not a universal rendering format.

## Phase 0 — Preserve the current flight prototype

Before changing the world representation, keep the existing thruster/vehicle prototype as a known-good baseline.

Do not entangle the voxel rewrite with changes to:

- thruster force model;
- stabilizer;
- zero-G flight controls;
- camera controls;
- current vehicle physics tuning.

The voxel work should initially integrate around that working prototype.

## Phase 1 — Build the generic voxel core

This is the highest priority.

### 1.1 Data model

Create project-owned core types conceptually similar to:

```text
VoxelGrid3D
VoxelChunk3D
VoxelMaterialDefinition
VoxelState
VoxelMesher
VoxelCollisionCompiler
VoxelRebuildScheduler
```

The core data model should use integer voxel coordinates and compact data rather than one node per voxel.

A voxel should be able to hold at least:

```text
material_id
health / damage state
flags as needed
```

The material definition should be able to provide both gameplay and rendering information.

### 1.2 Small voxel scale

Experiment with substantially smaller voxels than the Godot Foundation Minecraft-like demo, for example roughly 0.1–0.25 m depending on ship/world scale.

The voxel size must remain configurable until visual quality and performance are measured.

### 1.3 Chunking

Start with a simple chunk size such as 8³ or 16³ voxels and measure.

A voxel edit should dirty:

- its own chunk;
- a neighboring chunk only when the edited voxel touches a chunk boundary.

### 1.4 Exposed-face meshing

First implementation should follow the proven Godot Voxel Game Demo pattern:

```text
for each occupied voxel:
    inspect six neighbors
    emit only visible faces
```

Use `SurfaceTool` / `ArrayMesh` or an equivalent project-owned mesher.

Do not create a visible cube node for every voxel.

### 1.5 Material grouping

Generated geometry should group faces by voxel material so a chunk can render as a small number of surfaces:

```text
Chunk ArrayMesh
  surface: steel
  surface: titanium
  surface: glass
  surface: polymer
```

Transparent materials require their own visibility/rendering rules.

### 1.6 Threaded rebuilds

Mesh computation may use worker threads where safe.

Scene-tree, rendering-resource swaps and physics changes must occur on appropriate engine threads.

Large edits/explosions should use a rebuild budget so multiple dirty chunks do not cause a single-frame hitch.

### 1.7 Collision compilation

Do **not** copy the educational demo's one-collider-per-voxel approach.

The project needs simplified collision per chunk, initially via merged boxes/convex regions or another compiled representation.

The goal is:

```text
many occupied voxels
        -> few collision shapes
```

### 1.8 First proof

Before ship crafting, prove the voxel core on a small organic asteroid/rock:

- small voxels;
- generated rounded/irregular volume;
- merged visible geometry;
- material assignment;
- add/remove voxel at runtime;
- localized chunk rebuild;
- acceptable collision cost.

This is the first milestone.


## Planet-scale streaming direction

The large-world plan should treat each detailed planetoid as a streamed local terrain domain instead of keeping every body's high-resolution voxel data resident at once.

Conceptually:

```text
STAR SYSTEM / SPACE DOMAIN
  -> cheap distant planet proxies
  -> asteroid fields / stations / encounter markers
  -> detect approach to a detailed body
        |
        v
PLANET DOMAIN
  -> atmosphere / sky profile
  -> local gravity
  -> voxel terrain viewer centered on players
  -> load/generate nearby terrain chunks
  -> unload distant chunks
  -> local props/enemies/missions streamed by region
```

The atmosphere is useful visually because once the player descends far enough the local sky/atmosphere can dominate the view, but it is **not** the reason streaming works. Streaming must still explicitly control CPU/GPU memory, physics, terrain chunks, AI, props and mission assets.

### Strong candidate: Zylann Voxel Tools

Before writing our own planet-scale paging/LOD layer, evaluate **Zylann/godot_voxel (Voxel Tools)**. Its terrain nodes already solve many of the infrastructure problems we were about to implement manually:

- chunk/block based voxel storage;
- background threaded generation/meshing;
- loading and unloading blocks around one or more viewers;
- editable terrain with local remeshing;
- LOD terrain for much larger view distances;
- stream-backed persistence where only nearby blocks remain resident;
- custom generators and custom voxel channels/material data.

For our target Godot version, Voxel Tools 1.7 has a Godot 4.7.2 custom build and a GDExtension edition. Prefer evaluating the GDExtension first so the project can remain on an official Godot build unless the module edition proves necessary.

Also study the public **solar_system_demo** built on Voxel Tools. It is unusually close to our intended proof: editable voxel planets/moons, caves/ravines, ground-to-space spacecraft travel, per-planet persistence and origin shifting. Use it as an architecture reference rather than assuming we need to invent planet streaming from scratch.

### Planet representation tiers

A planet should have multiple representations, not one globally detailed sphere:

```text
VERY FAR
  tiny impostor / proxy sphere

FAR SPACE
  low-cost spherical mesh + atmosphere

NEAR ORBIT
  chunked LOD terrain begins contributing visible detail

SURFACE / CAVES
  high-resolution voxel blocks around active viewers
  physics + resources + enemies + props

BEHIND / FAR SIDE
  no full-resolution terrain resident unless another player requires it
```

In multiplayer, terrain residency is the union of regions needed by active player/viewer positions, while authoritative edited voxel state persists independently of whether a chunk is currently loaded.

### Scene/content streaming above the voxel layer

Voxel streaming only solves terrain. Build a separate region/content streamer for non-voxel content:

```text
PlanetRegion
  -> terrain chunks
  -> vegetation/rocks
  -> resource nodes
  -> enemies
  -> structures
  -> mission actors
  -> audio/ambient profile
```

As players cross region boundaries, instantiate nearby gameplay content and release or pool distant content. Mission state must remain logical/persistent even if its scene nodes are unloaded.

## Phase 2 — Damage, destruction and local individuality

Once the voxel substrate works, make it destructible before building the full ship editor.

### 2.1 Voxel health/material resistance

Each material definition should provide damage-relevant values such as:

- health;
- hardness;
- penetration resistance;
- density;
- thermal resistance where useful.

### 2.2 Local impact

Implement a minimal damage operation:

```text
impact position
impact energy/radius
        -> affected voxel coordinates
        -> material resistance
        -> changed/destroyed voxel state
        -> dirty chunks
```

### 2.3 Destruction backend evaluation

Evaluate **Voxel Destruction** here, not earlier.

Use it either as:

- a direct wrapped backend if it works with our moving-body architecture;
- or a source for algorithms such as flood fill, debris management, health and threaded destruction.

Keep our data model as the source of truth so the project is not locked to an addon representation.

### 2.4 Debris policy

Small debris:

```text
visual/local only
not networked
short lifetime
```

Meaningful fragments:

```text
connectivity/structural separation
        -> independent physical object
```

### 2.5 Internal exposure proof

Create a simple test object containing an internal module behind voxel armor.

Required proof:

1. fire/damage the hull;
2. create a real hole;
3. expose the internal object;
4. hit/damage the internal object through the hole.

This validates the core combat/crafting premise before implementing the full spacecraft builder.

## Phase 3 — Spacecraft construction and crafting

After construction and destruction share the same voxel representation, build the player-facing ship system.

### 3.1 Chassis

Craft a chassis/frame as a manufactured base piece.

It defines:

- structural skeleton;
- coordinate/grid bounds;
- module sockets/hardpoints;
- baseline mass;
- major structural attachment paths.

### 3.2 Functional modules

Install conventional modules such as:

- engines;
- thrusters;
- reactor;
- batteries;
- cockpit/stations;
- fuel;
- weapons;
- sensors;
- cargo;
- life support.

These remain logical gameplay components and do not become arbitrary hull voxels.

### 3.3 Runtime voxel hull editor

Build the player-facing editor around the shared voxel grid.

Initial tools:

```text
ADD
REMOVE
PAINT MATERIAL
BRUSH
LINE
BOX/FILL
MIRROR
SELECT
COPY/PASTE
UNDO/REDO
X-RAY
```

The user experience can borrow patterns from GoBuild, but runtime code must remain independently implemented.

### 3.4 Material crafting

Hull material must simultaneously drive:

- crafting cost;
- visual PBR appearance;
- mass;
- health/resistance;
- penetration behavior;
- possibly thermal/electrical behavior later.

### 3.5 Flight integration

Construction changes must feed the existing vehicle physics:

```text
chassis mass
+ modules
+ voxel materials
+ fuel/cargo
= total mass / center of mass
```

Verify that differently armored ships genuinely fly differently with the same engine configuration.

### 3.6 Physical module handling

Evaluate a project-owned GDScript version of the useful Physics Arsenal interaction pattern for large components/cargo:

```text
ray interaction
+ physical grab pivot
+ forces/damping
+ torque/damping
+ joint
```

Do not require .NET solely for this feature.

## Phase 4 — Multiplayer

Multiplayer comes **after** the object/state architecture is stable.

Doing it earlier would force networking around data structures that are still changing.

### 4.1 Authority

Host authoritative for:

- vehicle physics;
- crafting validation;
- voxel damage;
- structural separation;
- important module state.

### 4.2 Replicate semantic state, not generated geometry

Construction examples:

```text
ADD_VOXEL(position, material_id)
REMOVE_VOXEL(position)
PAINT_VOXEL(position, material_id)
ADD_MODULE(...)
REMOVE_MODULE(...)
```

Damage examples:

```text
impact event
or
changed voxel state
```

Clients rebuild their own local chunk meshes.

Never send `ArrayMesh` geometry over the network as gameplay state.

### 4.3 LinkUx

LinkUx remains the leading candidate behind our own `NetworkService` abstraction for ENet/Steam/session plumbing.

Ship snapshot/interpolation code should remain project-owned, especially quaternion orientation and Jolt authoritative state.

### 4.4 Late join

A late joiner receives:

- current ship blueprint;
- current modules;
- current voxel/material state and damage state;
- current important detached entities;
- current gameplay state.

Not historical debris simulation.

## Phase 5 — Crew and gameplay subsystems

Once the shared ship works in multiplayer, integrate supporting systems in small isolated layers.

### Crew movement

Use **Basic 3D Character Controller** as an MIT reference/base, but adapt it into project-owned movement modes:

```text
SURFACE
LOCAL_GRAVITY
EVA_ZERO_G
```

Do not keep the original assumption that Y is always gravity-up.

### Interaction

Add `CrewInteractionController` / `PhysicsGrabber` for:

- carrying cargo;
- moving modules;
- tools;
- repairs;
- loading resources;
- physical ship interaction.

### Generic gameplay components

Evaluate **GodotNodes+** selectively for:

- Health;
- Damage;
- Shield;
- Cooldown;
- Status effects;
- Lifespan;
- Hitbox/Hurtbox;
- object pooling;
- state machines.

Do not use node-per-voxel components.

### Cameras

Create a project-owned `CameraFeedManager` based on the Godot **Dynamic Split Screen Demo** patterns:

```text
pilot camera
artillery camera
rear camera
docking camera
security camera
drone/turret camera
```

Feeds may appear as:

- fullscreen;
- split-screen;
- picture-in-picture;
- cockpit monitors;
- interior screens.

### Combat aiming

Evaluate **BallisticSolutions** as the aiming/interception solver for:

- gunner lead indicators;
- AI turrets;
- moving-target interception;
- point defense.

Projectile simulation/damage remains project-owned.

### Asset pipeline

Use **Advanced Model Import** later as an editor/production utility when the project starts ingesting many external GLB/FBX assets and needs material normalization/extraction.

## Phase 6 — Expand the world

Only after the core loop is technically solid should the project spend heavily on content/world breadth.

### Planetoids and asteroids

Reuse the voxel substrate for selected world bodies:

- organic small-voxel surfaces;
- mining;
- damage/craters where useful;
- chunk streaming;
- local gravity.

The existing asteroid/space work becomes a useful basis rather than being discarded.

### Atmospheres and lighting

Then integrate/test:

- LightingEnvironmentController profiles;
- Clouds for Little Planets for selected larger planetoids;
- distance/quality tiers;
- reflection/GI/fog rules already captured in the lighting skill.

### Enemies

Enemy architecture can choose the appropriate representation per type:

```text
small drone -> conventional mesh
armored ship -> module + voxel hull
large destructible boss -> voxel/destructible regions
creature -> conventional animated mesh
```

Do not force enemy variety through one representation.

### Exploration systems

Then add progressively:

- resources/mining;
- stations;
- ruins;
- planets/planetoids;
- inventory/cargo economy;
- enemies;
- missions;
- survival systems;
- crew repair/engineering gameplay.

## Recommended integration order summary

```text
CURRENT FLIGHT PROTOTYPE
        |
        v
1. VOXEL CORE
   data + chunks + meshing + collision
        |
        v
2. DESTRUCTION
   damage + holes + debris + internal exposure
        |
        v
3. SHIP CONSTRUCTION / CRAFTING
   chassis + modules + voxel hull + materials + mass
        |
        v
4. MULTIPLAYER
   authority + semantic replication + late join
        |
        v
5. CREW / CAMERAS / COMBAT / INTERACTION
   character + grab + health + feeds + ballistics
        |
        v
6. WORLD EXPANSION
   planetoids + atmospheres + enemies + resources
```

This order is intentional: every phase should create infrastructure used by the next one instead of building disposable systems.

## Addon/reference placement by phase

| Resource | Phase | Role |
|---|---:|---|
| Godot Foundation Voxel Game Demo | 1 | Chunk/data/exposed-face meshing reference |
| Voxel Destruction | 2 | Strong candidate/reference for destruction, flood fill, debris |
| GoBuild | 3 | UX/operation/undo reference only; no runtime code reuse because GPL v3 |
| Static Mesh Merger | 3 | Utility for conventional fixed module/chassis geometry |
| Physics Arsenal | 3/5 | Physics interaction reference; port useful pattern to GDScript |
| LinkUx | 4 | Multiplayer/session/transport candidate behind our wrapper |
| Godot 3D Multiplayer Template | 4 | Authority/validation/reference patterns |
| Basic 3D Character Controller | 5 | Crew movement starting point/reference |
| Dynamic Split Screen Demo | 5 | Multi-camera/SubViewport composition reference |
| BallisticSolutions | 5 | Ballistic/interception math candidate |
| GodotNodes+ | 5 | Selective reusable gameplay components |
| Advanced Model Import | 5/6 | Editor asset-import workflow utility |
| Clouds for Little Planets | 6 | Atmosphere/cloud candidate for selected planetoids |
| Instant Realistic Light | 6 | Knowledge already absorbed into lighting skill |
| Maaack Game Template | later shell/polish | Menus/options/pause/credits |

## Immediate next milestone

The next substantial experiment should therefore **not** be multiplayer, menus, crew or enemies.

It should be a small isolated voxel proof that answers:

1. Can we represent a rounded/organic object with small voxels while keeping voxel data editable?
2. Can contiguous voxels render as a small number of merged chunk meshes?
3. Can we remove voxels and rebuild only local dirty chunks?
4. Can the new exposed geometry appear immediately after damage?
5. Can collision be regenerated without one collider per voxel?
6. Can this run without visible frame spikes at a voxel density appropriate for a spacecraft hull?

If those answers are positive, use the same core for the spacecraft hull and then build destruction/crafting on top of it.
