# Game Design — Cooperative Modular Spacecraft

> Living design document. This captures long-term game ideas that should not be lost while the current vector-thruster experiment remains intentionally narrow.

## Core fantasy

The game is a cooperative, arcade-oriented 3D survival/exploration game built around a **shared modular spacecraft**. The craft is not just a predefined vehicle skin: players construct it, install functional systems, cover it with a material hull, damage it, repair it and operate it together.

The long-term design should make the same physical object participate in several systems at once:

- crafting and resource consumption;
- visual customization;
- mass and center of mass;
- propulsion and handling;
- structural integrity;
- armor and penetration;
- internal systems damage;
- crew safety;
- multiplayer cooperation.

The vehicle should feel understandable and physical without becoming a full aerospace engineering simulator.

## Spacecraft construction model

The current preferred construction flow has three distinct layers.

### 1. Chassis / structural frame

The player first crafts a **chassis** as a single manufactured piece or predefined structural frame.

The chassis provides:

- the core structural skeleton;
- a stable coordinate system and attachment grid;
- hardpoints / sockets for internal systems and large external modules;
- baseline mass and structural strength;
- major load paths that determine when a large section can detach.

The chassis should not be represented as thousands of destructible cosmetic voxels. It is the structural backbone beneath the hull.

Different chassis can define different roles, dimensions and internal layouts while still allowing extensive player customization.

### 2. Internal systems and functional modules

Players install actual functional components onto or inside the chassis, for example:

- cockpit / control station;
- vector thrusters;
- main engines;
- gyroscope / flight controller;
- reactor or power source;
- batteries;
- fuel tanks;
- weapons;
- sensors;
- shields;
- life support;
- cargo;
- doors / airlocks;
- seats and crew stations.

These remain logical gameplay entities even if some of their visual geometry is later merged or optimized for rendering.

Each component can have its own:

- mass;
- health;
- power draw / production;
- heat characteristics;
- functional degradation curve;
- mount points;
- network identity where gameplay requires it.

Example damage behavior:

```text
Engine
100% -> normal thrust
 70% -> reduced efficiency
 40% -> intermittent or heavily reduced thrust
 10% -> severe failure / fire risk
  0% -> disabled, detached or explosive failure depending on type
```

### 3. Player-built voxel hull / armor

After the chassis and systems exist, the player enters an **in-game visual construction editor** and draws the exterior hull using voxels, conceptually similar to a MagicaVoxel-style workflow.

The voxel hull is not merely cosmetic. Every voxel has a material and therefore participates in mass, cost, appearance and damage resistance.

The important design principle is:

> **The same voxel structure that the player builds is the structure that later receives and shows damage.**

There should not be a separate decorative shell that is replaced by unrelated destruction effects.

## In-game voxel construction editor

The construction editor should appear inside the game rather than requiring the Godot editor.

The basic workflow:

1. Show the bare chassis.
2. Optionally show installed systems.
3. Let the player add/remove hull voxels around the chassis.
4. Paint or replace voxel materials.
5. Continuously calculate cost, total mass and relevant structural statistics.
6. Save the result as part of the ship blueprint.

### Core tools

Initial useful tools:

- add voxel;
- remove voxel;
- material paint / replace;
- brush sizes;
- line tool;
- box / volume fill;
- flood fill where appropriate;
- box selection;
- copy / paste selection;
- mirror / symmetry across X, Y and/or Z;
- undo / redo;
- hide / isolate construction layers;
- X-ray / transparent hull view;
- camera orbit / pan / zoom optimized for editing.

Later tools may include templates, decals, smoothing or more advanced geometry operations, but the first editor should prioritize speed and clarity.

### Editor visibility modes

Suggested modes:

```text
STRUCTURE
  chassis / structural frame

SYSTEMS
  chassis + installed functional components

HULL
  voxel hull / armor

ALL
  complete spacecraft

X-RAY
  translucent or hidden hull with internal systems visible
```

This should make it practical to deliberately protect important components with thicker or stronger material.

## Voxel data model

A voxel must **not** be a Godot Node.

Use compact data, conceptually:

```text
ShipVoxelGrid
Vector3i -> material_id + health/state
```

or an equivalent chunked representation.

Example:

```text
(12, 4, 7) = TITANIUM
(13, 4, 7) = TITANIUM
(14, 4, 7) = GLASS
(15, 4, 7) = EMPTY
```

Rendering and collision are generated from this authoritative data.

### Chunking

The hull should be divided into spatial chunks, for example 8x8x8 or 16x16x16 voxels, to avoid rebuilding the entire spacecraft after every edit or hit.

```text
ShipVoxelHull
├── Chunk 0
├── Chunk 1
├── Chunk 2
└── ...
```

A changed voxel marks only its containing chunk, plus any directly affected neighboring chunk, as dirty.

Possible rendering implementations include MultiMesh-based voxels, generated exposed-face meshes, or another optimized representation. The source voxel grid remains independent of how it is rendered.

## Ship materials

Material is gameplay data, not just a Godot `Material`.

Use a project-owned resource such as `ShipMaterialDefinition` containing both physical/gameplay properties and visual properties.

Potential fields:

```text
id
name
crafting_cost
density
max_health
hardness
toughness
penetration_resistance
thermal_resistance
conductivity
flammability / ignition behavior (future)
metallic
roughness
transparency / opacity
color / texture references
```

Example material roles:

| Material | Mass | Armor | Visual / gameplay role |
|---|---:|---:|---|
| Plastic / polymer | Very low | Low | Cheap, matte, internal covers |
| Aluminum | Low | Medium | Lightweight general structure |
| Steel | High | High | Cheap heavy armor |
| Titanium | Medium | Very high | Strong premium armor |
| Glass | Medium | Low impact resistance | Transparent windows |
| Ceramic | Low/medium | Specialized | Thermal / energy protection |
| Composite | Low | Medium/high | Expensive lightweight protection |
| Advanced space alloy | Low/medium | Extreme | Late-game material |

The exact statistics are game balance values, not real-world engineering tables.

### Visual material behavior

Material definitions should also drive rendering, including:

- transparent glass;
- shiny polished metal;
- rough painted metal;
- matte polymer;
- ceramic;
- emissive or special advanced materials.

A small shared material library is preferable to hundreds of per-voxel duplicated Godot materials.

## Mass and flight integration

Every construction action can affect the flight model.

```text
chassis mass
+ installed modules
+ voxel hull material mass
+ cargo / fuel
= spacecraft total mass
```

The generated mass and center-of-mass data feed the existing force/thruster simulation.

A heavily armored craft with the same engines should accelerate and rotate differently from a lightweight craft.

This relationship is central to the building gameplay: protection, cost and maneuverability trade against each other.

## Organic damage and penetration

Avoid reducing the entire craft to one global HP bar.

A weapon hit should interact with the hull at a spatial location.

Conceptual flow:

```text
weapon impact
    -> hull voxel(s)
    -> material absorbs / resists energy
    -> voxel health decreases
    -> voxel may be destroyed
    -> remaining penetration energy continues inward
    -> internal module / chassis / crew may be hit
```

Different weapons should create different spatial damage patterns:

- laser: narrow, localized, potentially deep or heat-oriented damage;
- ballistic cannon: localized kinetic damage;
- railgun: strong penetration through multiple hull layers;
- missile: radial damage and debris impulse;
- plasma / energy weapon: specialized thermal / energy behavior.

Exact models should stay arcade-readable rather than becoming a full finite-element simulation.

## Exposed internals

A major goal of the voxel hull is that damage can visibly expose the internal ship.

Once armor is removed, later shots can strike:

- engines;
- thrusters;
- reactor;
- batteries;
- fuel tanks;
- weapons;
- control systems;
- cargo;
- crew.

This makes placement matter. A player may deliberately use strong armor around a reactor or accept a lighter but riskier design to improve mass and handling.

## Structural separation

Hull voxels and structural integrity are related but are not identical.

The chassis/frame defines important structural load paths. Destroying a few arbitrary outer voxels should not make half the spacecraft detach.

Large separation occurs when structural rules indicate a section is no longer attached to the main chassis, for example:

```text
wing hull heavily damaged
+ wing frame / attachment destroyed
= wing detaches
```

Detached gameplay-relevant sections can become their own physical entities. Small fragments should usually be cheap visual debris rather than fully networked rigid bodies.

## Crew and decompression — future extension

The architecture should allow later simulation of crew exposure without requiring it in the first destruction prototype.

Possible future chain:

```text
hull breach
 -> compartment exposed
 -> pressure / oxygen loss
 -> crew danger
 -> repair / seal gameplay
```

Direct projectile or explosion damage may also hurt crew when the hull no longer protects them.

This should remain optional and staged; first prove hull damage and internal-system damage.

## Voxel Destruction addon evaluation

Candidate:

- Terabase Studios — **Voxel Destruction**
- Source: `Terabase-Studios/Godot-Voxel-Destruction`
- License: MIT
- Godot 4.7+
- Current status during evaluation: active but marked unstable.

This is currently a **strong candidate for a core destruction backend or a source of reusable architecture**.

Useful properties observed in its implementation:

- `VoxelObject` renders through `MultiMeshInstance3D` rather than one node per voxel;
- health can be tracked globally and per voxel;
- damage is spatial;
- detached regions can be processed through flood-fill;
- debris can be disabled, MultiMesh-based or physical rigid bodies;
- collision is regenerated as voxels change;
- work is distributed through `WorkerThreadPool`;
- there is an optional Rust/GDExtension acceleration path;
- `VoxelMarker` can associate gameplay logic with a specific voxel and signal when it is damaged/destroyed.

Important caveat: its own `VoxelObject.physics` / RigidBody mode is marked experimental and warns about clipping during damage. Therefore the preferred design is to retain **our spacecraft `RigidBody3D` as the authoritative craft body** and integrate destruction below that abstraction instead of replacing the vehicle physics architecture wholesale.

### Desired experiment

Before accepting it as core:

1. Build a small spacecraft section using our intended hull data.
2. Render it with the addon or an adapter around it.
3. Fire a localized hit.
4. Destroy a real hole.
5. Expose an internal component.
6. Damage that component through the hole.
7. Detach one structurally meaningful fragment.
8. Confirm the main spacecraft remains controlled by our Jolt `RigidBody3D`.
9. Measure hitching, collision regeneration and memory use.

## GoBuild addon evaluation

Candidate:

- Marcel Roodt — **GoBuild**
- Current Store version during evaluation: v0.10.0
- Godot 4.6-targeted editor plugin
- License: **GPL v3**
- Store status: marked unstable / active development.

GoBuild is an in-editor polygon mesh modeller, not a voxel construction system. It supports vertex/edge/face selection, transform gizmos, primitives, box selection, extrude/inset/subdivide/loop cuts, UV tools and material palettes.

### What is useful to learn from it

The most relevant design pattern is its separation between **editable source data** and **rendered output**:

```text
editable mesh data
    -> modelling operation
    -> bake
    -> ArrayMesh
```

Its `GoBuildMesh` resource stores vertices, faces, edges, material indices and related topology, while `GoBuildMeshInstance` bakes that data into a Godot `ArrayMesh`. This is conceptually very close to what our voxel hull should do:

```text
ShipVoxelGrid
    -> build/edit operation
    -> rebuild dirty chunk
    -> runtime render mesh / MultiMesh
```

Other useful UX/architecture ideas:

- explicit edit modes;
- selection manager independent from core geometry data;
- click / shift-click / ctrl-click / box selection;
- transform/interaction gizmos;
- operations separated from the editable data model;
- undo/redo based on operations/snapshots;
- fast preview updates while dragging followed by a full final bake;
- named reusable material palettes;
- material indices rather than duplicating a material object for every face.

### What should *not* be copied directly

The player-facing hull editor does not need general polygon topology editing such as arbitrary edge loops, UV island editing or freeform face extrusion. A voxel editor can be dramatically simpler and easier to use with a controller.

More importantly, GoBuild is GPL v3. Unless the game is intentionally distributed under GPL-compatible terms, **do not copy GoBuild source code into the runtime game or create a derivative runtime component from its implementation**.

Use it as:

- an editor-time development tool if useful;
- a UX reference;
- an architecture reference at the level of ideas/patterns;
- a source of test cases for what makes 3D editing comfortable.

For the runtime construction editor, reimplement the required interaction and data-flow concepts independently in project-owned code.

### Current verdict

**Useful reference, not a runtime dependency.**

The parts most worth reproducing independently are selection, material palette UX, edit-operation architecture, undo/redo and preview-vs-final rebuild behavior.

## Godot Foundation Voxel Game Demo evaluation

Candidate/reference:

- Godot Foundation — **Voxel Game Demo**
- Source: `godotengine/godot-demo-projects/3d/voxel`
- License: MIT for the demo code; bundled third-party textures have their own licenses.
- Godot 4.7 Asset Store demo.

This demo is valuable primarily as a **small, readable reference implementation of chunked editable voxel data using only built-in Godot/GDScript APIs**. Its block size is intentionally Minecraft-like and is not the visual scale desired for the spacecraft hull, but the core coordinate/chunk/meshing logic is transferable to much smaller voxels.

### Useful implementation patterns

The demo stores each chunk as a `Dictionary[Vector3i, int]`, where the integer is the block/material ID. Its chunks are 16x16x16 and are addressed separately from local voxel coordinates. This maps cleanly to our desired model:

```text
ShipVoxelGrid
  chunk_coord -> ShipVoxelChunk

ShipVoxelChunk
  local_voxel_coord -> material/state
```

The `VoxelWorld.set_block_global_position()` flow is especially relevant:

```text
ship-local voxel coordinate
    -> determine chunk coordinate
    -> determine local coordinate inside chunk
    -> mutate authoritative voxel data
    -> mark/rebuild changed chunk
    -> if voxel lies on a chunk boundary, also rebuild affected neighbor
```

That is almost exactly the dirty-chunk behavior needed for runtime ship construction and destruction.

### Exposed-face meshing

The demo does **not** create a visible cube mesh per block. For every occupied voxel it checks the six neighboring positions and emits a face through `SurfaceTool` only when that face is exposed. It also checks neighboring chunks when the voxel lies on a chunk boundary.

This is directly useful for a small-voxel spacecraft hull because the interior faces between adjacent armor voxels should never be sent to the renderer.

Conceptually:

```text
for each solid voxel:
    for each of 6 directions:
        if neighbor is empty/compatible-transparent:
            emit face
```

For our implementation this should be generalized from `block_id` to `ShipMaterialDefinition`, with material-aware visibility rules. Glass/translucent materials in particular need more careful face rules than the demo's simple transparent-block check.

### Threading and rebuild scheduling

The demo generates chunk mesh data through `WorkerThreadPool`, while physics/collision changes remain on the main thread. It also limits chunk creation/deletion work per frame to reduce spikes.

Those are important patterns for us:

- authoritative voxel data may change immediately;
- dirty chunk mesh calculation can happen asynchronously where safe;
- final RenderingServer/scene-tree/physics mutations happen on the appropriate thread;
- large edits or explosions should be budgeted across frames rather than rebuilding every affected chunk at once.

For the spacecraft there is no need for infinite-world render-distance streaming, but the **work budgeting** pattern is still relevant when many hull chunks are damaged simultaneously.

### What should not be copied directly

The demo gives **every block its own `CollisionShape3D`** inside a `StaticBody3D`. This is acceptable for an educational terrain demo, but it is not appropriate for our small-voxel moving spacecraft. Hundreds or thousands of per-voxel collision shapes attached to the ship would be too expensive and would conflict with our existing authoritative `RigidBody3D` design.

Our collision layer should instead compile simplified/chunked collision from voxel occupancy, use merged boxes/convex shapes where possible, and update only dirty regions. Voxel Destruction's collision strategies are a better additional reference for this part.

The demo also performs a full chunk mesh regeneration after a changed block. That is a good first implementation for our finite hull, but later optimization can include:

- chunk sizes tuned for the expected ship scale;
- material grouping/surfaces;
- greedy meshing to merge coplanar adjacent faces;
- cached neighbor/occupancy information;
- specialized transparent-material passes;
- incremental collision compilation.

### Current verdict

**Very useful MIT reference for our core `ShipVoxelGrid` / `ShipVoxelChunk` implementation.**

Do not adopt it as a dependency. Extract/reimplement the transferable architecture around chunk coordinates, local voxel coordinates, exposed-face generation, neighbor-boundary invalidation, worker-thread mesh generation and frame-budgeted rebuilds.

Because our voxel hull is a finite moving object rather than an infinite terrain, our implementation can be substantially simpler than a general voxel-world engine while still using the same proven chunking concepts.

## Static Mesh Merger role after voxel-hull decision

Static Mesh Merger remains useful but is no longer expected to be the primary hull solution.

Potential uses:

- chassis visuals;
- fixed internal decorative geometry;
- prefabricated functional modules;
- stations / structures;
- enemy meshes where voxel construction is not required.

The player-built hull should stay backed by voxel data so construction and destruction operate on the same representation.

## Multiplayer implications

Construction and destruction must synchronize **semantic operations/state**, not generated geometry.

### Construction

Send operations such as:

```text
ADD_VOXEL(position, material_id)
REMOVE_VOXEL(position)
PAINT_VOXEL(position, material_id)
ADD_MODULE(module_id, socket, transform)
REMOVE_MODULE(module_instance_id)
```

The host validates the operation, updates the authoritative `ShipBlueprint` / voxel state, and clients rebuild the relevant chunk locally.

Do not transmit generated `ArrayMesh` data over the network.

### Damage

The host remains authoritative for gameplay damage.

Replicate deterministic/semantic damage information such as:

```text
object_id
impact_position
impact_direction
weapon/damage profile
energy or radius
seed where needed
```

or replicate the resulting changed voxel IDs/state if deterministic reproduction proves unreliable.

Small debris is local visual simulation. Only debris or detached sections that matter to gameplay become network entities.

Late joiners receive current ship blueprint/module state plus current hull damage state, not the historical transform of every fragment ever created.

## Suggested software boundaries

Conceptual long-term classes/services:

```text
ShipBlueprint
ShipChassisDefinition
ShipModuleDefinition
ShipModuleInstance
ShipMaterialDefinition
ShipVoxelGrid

ShipConstructionLogic
ShipConstructionEditor
ShipSelectionService
ShipBuildOperation
ShipUndoHistory

ShipVoxelRenderer
ShipVoxelChunk
ShipCollisionCompiler

ShipDamageResolver
ShipPenetrationLibrary
ShipStructuralIntegrity
ShipDestructionAdapter

ShipMassCalculator
ShipPhysicsCompiler

ShipNetworkController
```

Keep gameplay truth separate from rendering and editor UI.

## Current addon/tool map

| Candidate | Intended role | Current verdict |
|---|---|---|
| Maaack Game Template | Main menu, options, pause, credits | Integrate as addon later |
| Clouds for Little Planets | Planetoids, atmosphere, clouds | Strong candidate; isolated test first |
| Instant Realistic Light | Lighting recipe/reference | Knowledge absorbed into project lighting skill |
| Static Mesh Merger | Merge fixed mesh geometry / reference runtime compiler | Utility / source reference |
| LinkUx | Multiplayer transport/session/replication helpers | Leading candidate behind project-owned network abstraction |
| Godot 3D Multiplayer Template | Multiplayer patterns | Reference source, not framework dependency |
| Voxel Destruction | Destructible hull, spatial damage, debris | Strong candidate; may become core destruction backend |
| GoBuild | In-engine construction/editing UX ideas | Reference only; runtime code must be independently implemented due GPL v3 |
| Godot Foundation Voxel Game Demo | Chunked voxel data, exposed-face meshing, editing/rebuild flow | Strong MIT reference for project-owned `ShipVoxelGrid` implementation |

## Near-term validation sequence for construction/destruction

Do not build the full editor at once.

A sensible progression is:

1. Define `ShipMaterialDefinition` with at least steel, titanium and glass.
2. Create a small `ShipVoxelGrid` test volume around a simple chassis.
3. Render it efficiently without one Node per voxel, initially using exposed-face chunk meshing derived from the Godot Voxel Game Demo pattern.
4. Add add/remove/paint operations at runtime.
5. Add symmetry and undo/redo.
6. Derive mass from material density and verify flight changes.
7. Integrate one localized damage event.
8. Open a real hole in the hull.
9. Place an internal engine/reactor dummy behind the hull and allow damage through the hole.
10. Test structural detachment of one section.
11. Measure performance and determine whether Voxel Destruction should be used directly, wrapped, or mined for ideas.
12. Evaluate greedy meshing and simplified/chunked collision after the basic data/edit loop works.
13. Only then expand to polished construction UI, multiplayer editing and more material types.
