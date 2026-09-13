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

## Current default test values

```text
starter radius:        42 m
voxel resolution:      64
requested voxel size:  1.25 m
actual size:            clamped as needed to fit padded radius
surface noise:          0.24
cave frequency:         0.085
cave threshold:         0.50
outer shell:            5 m
main tunnel radius:     5.5 m
chamber radius:         10 m
```

At radius 42 m with surface padding, resolution 64 yields roughly 1.7 m cells. This is already much finer than the previous ~4 m asteroid cells, but it is **not** the final ship-hull voxel scale. Ship armor can later use much smaller voxels (roughly 0.1–0.25 m) because its volume and streaming requirements differ from world terrain.

## Entrances

The prototype deliberately creates two entrances:

- primary entrance on the +X side;
- secondary entrance on the -Z side.

Temporary emissive beacons and local lights mark the two entrances so testing does not require searching the entire asteroid.

## Occlusion note

The former starter asteroid used a simple `SphereOccluder3D`. That is valid for a solid rock but wrong once the body has navigable caves: a closed spherical occluder would claim that cave openings/interiors are solid.

Therefore the cavern version disables the sphere occluder. Later voxel/chunk occlusion should use geometry-aware occluders or rely on normal depth/occlusion behavior rather than a fake closed volume.

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
3. Voxel generation log reports a 64-resolution cavern volume and non-zero carved voxel count.
4. The asteroid reads as irregular rock rather than a smooth sphere or giant Minecraft blocks.
5. Both marked entrances are visibly open.
6. Flying through an entrance reaches the central cavern without collision sealing the tunnel.
7. Branch tunnels reach multiple distinct chambers.
8. Interior walls are rendered from newly exposed voxel faces.
9. No obvious false occlusion occurs while looking through or from inside caves.
10. Startup generation and trimesh collision creation do not cause an unacceptable hitch.

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
