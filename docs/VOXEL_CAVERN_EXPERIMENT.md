# Voxel Cavern Experiment

This experiment is the first concrete proof for the voxel-first roadmap.

## Goal

Replace the starter asteroid's mostly solid voxel sphere with a **small-voxel organic rock volume containing navigable internal caves**, closer in spirit to Deep Rock Galactic than Minecraft.

The immediate proof is geometric and rendering-oriented:

- irregular outer rock surface;
- smaller voxel scale than the previous asteroid test;
- one merged `ArrayMesh` generated only from exposed voxel faces;
- internal chambers and tunnels cut from the same voxel occupancy field;
- at least two guaranteed surface entrances;
- cave collision generated from the same mesh;
- no fake solid spherical occluder while caves are active.

The voxel data is still generated transiently in this first experiment. The next architectural step after validating the result visually/performance-wise is to retain the voxel grid as authoritative runtime state, split it into dirty/rebuildable chunks, and then support local damage/edit operations.

## Cave layout

The generator combines two approaches:

1. **Guaranteed connected skeleton**
   - two entrances from the exterior;
   - one large central chamber;
   - three branch chambers;
   - capsule-shaped connecting tunnels.

2. **Procedural interior noise**
   - additional pockets and side passages;
   - only carved beneath a preserved outer shell;
   - explicit entrance tunnels are allowed to pierce the shell.

This avoids both failure modes of a simple noise-only cave generator:

- disconnected internal bubbles that cannot be reached;
- an asteroid that becomes uniformly hollow or sponge-like.

## Current temporary granular test values

```text
starter radius:        42 m
voxel resolution:      128
requested voxel size:  0.50 m
actual size:            still clamped as needed to fit padded radius
surface noise:          0.24
cave frequency:         0.085
cave threshold:         0.50
outer shell:            5 m
main tunnel radius:     5.5 m
chamber radius:         10 m
```

The earlier 64-resolution proof produced ~1.68 m cells and read too much like large Minecraft blocks. The isolated `experiment/voxel-granularity-pass` branch therefore temporarily doubles the dense resolution to 128 and requests 0.50 m cells for visual comparison.

This is **not** the production scaling strategy. A much larger planetoid combined with small cells would make one monolithic `resolution^3` occupancy array grow too quickly. Before enlarging the body substantially, move to chunked voxel storage/meshing so fine cells are paid for only where relevant.

Ship armor can later use even smaller voxels (roughly 0.1–0.25 m depending on ship scale) because its physical volume and streaming requirements differ from terrain.

## Entrances

The prototype deliberately creates two entrances:

- primary entrance on the +X side;
- secondary entrance on the -Z side.

Temporary emissive beacons and local lights mark the two entrances so testing does not require searching the entire asteroid.

## Occlusion note

The former starter asteroid used a simple `SphereOccluder3D`. That is valid for a solid rock but wrong once the body has navigable caves: a closed spherical occluder would claim that cave openings/interiors are solid.

Therefore the cavern version disables the sphere occluder. Later voxel/chunk occlusion should use geometry-aware occluders or rely on normal depth/occlusion behavior rather than a fake closed volume.

## Visual review corrections — ordered implementation

The first visual review identified several issues that should be corrected in dependency order rather than by only increasing constants.

### 1. Lighting/readability first

Before judging cave geometry or material distribution, make the scene readable:

- provide a clearly visible primary star/sun;
- align the main directional light with that visible source;
- increase restrained ambient fill without flattening space lighting;
- retain strong directional shadows;
- give the spacecraft forward headlights for cave navigation.

The first lighting pass on this branch now adds a visible warm primary star, a stronger aligned directional light, more readable ambient fill, and two spacecraft spotlights.

### 2. Material variety and emissive geology

The planetoid must stop reading as one uniformly colored cubic construction. Add real voxel material IDs for several geological families, initially something like:

```text
dark basalt / common rock
lighter silicate / fractured stone
metallic ore
iron-rich rock
crystal / iridescent mineral
emissive mineral
ice / glassy material where appropriate
```

These should evolve into `VoxelMaterialDefinition` data that eventually also drives hardness, density, mining value and damage behavior. Emissive/iridescent deposits should become sparse cave landmarks rather than global illumination.

### 3. Chunked fine-voxel substrate

The visual target is explicitly **not Minecraft**:

- small voxels;
- organic silhouettes;
- contiguous voxels compiled into merged geometry;
- authoritative voxels remain individually addressable;
- damaged regions rebuild locally.

Before combining much larger bodies with much smaller cells, refactor toward:

```text
VoxelGrid3D
  -> VoxelChunk3D
  -> local occupancy + material IDs
  -> exposed-face / improved surface meshing
  -> dirty chunk rebuild
  -> compiled collision
```

The current 128-resolution dense branch is only an interim comparison and should not be pushed to enormous resolutions.

### 4. Larger planetoid scale

After chunking makes fine cells affordable, increase the main navigable body's radius substantially so the spacecraft feels small relative to it. The starter object should read as a small planetoid / very large asteroid, while the far field can still contain many ordinary small asteroids.

### 5. Re-tune caves after scale is fixed

Keep the Deep-Rock-style principles:

- guaranteed surface entrances;
- large navigable chambers;
- branching tunnels;
- procedural side pockets;
- no false closed occluder;
- collision preserving openings.

But re-tune tunnel radius, chamber radius, shell thickness and branch density only after final cell size and planetoid scale are known.

### 6. Cave landmarks / luminous resources

Once material IDs exist, place rare self-emissive or iridescent geological deposits inside the cave system. These give navigation landmarks and later become mining/crafting resources. Caves should not be uniformly bright: ship lights plus sparse geological emission should create contrast.

### 7. Performance / LOD proof

Before populating the world with multiple detailed planetoids, measure:

- chunk generation time;
- visible triangle count;
- collision rebuild cost;
- high-detail streaming distance.

Only nearby bodies should use detailed voxel terrain; distant bodies should stay on cheap proxy meshes / MultiMesh. Greedy meshing or smoother extraction can be added when measurement shows they are needed.

## What this experiment does not prove yet

It does not yet implement:

- persistent `VoxelGrid3D` runtime state;
- chunk-local rebuilds;
- mining/damage;
- voxel health/material properties;
- debris;
- detached fragments;
- greedy meshing;
- compiled simplified voxel collision;
- multiplayer replication.

Those remain the next stages after this geometry/cavern proof is visually and performance validated.

## Validation checklist

1. Project parses on the target Godot branch.
2. Starter asteroid generates without startup errors.
3. Voxel generation reports the configured cavern volume and non-zero carved voxel count.
4. The planetoid reads as irregular rock rather than a smooth sphere or giant Minecraft blocks.
5. Both marked entrances are visibly open.
6. Flying through an entrance reaches the central cavern without collision sealing the tunnel.
7. Branch tunnels reach multiple distinct chambers.
8. Interior walls are rendered from newly exposed voxel faces.
9. No obvious false occlusion occurs while looking through or from inside caves.
10. Startup generation and trimesh collision creation do not cause an unacceptable hitch.
11. The primary light source is visually obvious and matches the directional illumination.
12. Ship headlights provide useful cave navigation without flattening the entire cave.

## Runtime smoke result — original 64-resolution proof, 2026-09-13

Validated locally through AI Local Access using Godot 4.7.1 stable.

Editor/headless project scan completed with exit code 0 and no parser/import failure. Runtime execution for 120 frames also completed with exit code 0 and generated the full space world.

Observed cavern generation metrics:

```text
radius=42.0
resolution=64
actual cell size=1.68 m
solid voxels=60,998
carved voxels=5,258
exposed faces=20,832
vertices=83,328
caves=true
```

The full world then generated 340 asteroids across 150 sectors and the vehicle spawned normally at y=50 m.

A separate normal Godot window was also launched successfully for visual inspection.

Remaining validation now applies to the newer granular/lighting branch: check the finer surface, sun direction/readability, headlights, cave proportions and performance before proceeding to material IDs and chunk architecture.

One non-fatal resource UID warning remains in the local editor cache for `world_settings.tres`; Godot falls back to the correct text resource path and runtime generation succeeds. This should be cleaned up separately rather than conflated with the cavern implementation.

## Follow-up if successful

Refactor the temporary occupancy buffer into the planned project-owned voxel core:

```text
VoxelGrid3D
  -> VoxelChunk3D
  -> exposed-face chunk mesher
  -> chunk collision compiler
  -> dirty rebuild scheduler
```

Then make the first destructive operation remove voxels from one chunk and rebuild only the affected region. That is the point where the visual "merged object" begins to recover local voxel individuality under damage without turning every voxel into a Godot node or rigid body.
