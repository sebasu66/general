# Voxel Tools study sandbox

This folder is intentionally separate from `experiments/vector-thruster-prototype`.

Its purpose is to study **Zylann Voxel Tools** and the upstream **Solar System Demo** without modifying the current spacecraft prototype.

## Upstream demo

The demo is included as a Git submodule at:

`experiments/voxel-tools-study/solar_system_demo`

Pinned upstream commit:

`7e6c95db11b6122ee44efc725fe284a84b1d2b08`

Source:

`https://github.com/Zylann/solar_system_demo`

License: MIT.

## Why this demo matters

It demonstrates several systems close to the current game direction:

- smooth voxel planets rather than visible Minecraft-style cubes;
- `VoxelLodTerrain` planet rendering;
- viewer-driven terrain detail;
- caves and ravines;
- runtime terrain editing;
- per-planet `VoxelStreamSQLite` persistence;
- atmosphere as a separate system;
- spaceship travel from ground to space;
- reference-body/origin shifting;
- props generated through `VoxelInstancer`.

## Local checkout

From `C:/DEV/general` on branch `experiment/voxel-granularity-pass`:

```powershell
git pull --ff-only origin experiment/voxel-granularity-pass
git submodule update --init --recursive experiments/voxel-tools-study/solar_system_demo
```

The demo project is then at:

`C:/DEV/general/experiments/voxel-tools-study/solar_system_demo`

## Engine requirement

The pinned demo expects Godot with the **Voxel Tools module**. It should not be opened with the vanilla Godot executable used by the current spacecraft prototype and assumed to work.

For this study, use **Voxel Tools 1.7**, whose current release provides a custom **Godot 4.7.2 stable + Voxel Tools 1.7** Windows editor build.

Production integration is a separate decision. The project should also evaluate the Voxel Tools **GDExtension** edition before adopting a custom Godot build, because GDExtension can run with official Godot builds/export templates.

## Study goals

Do not modify the main prototype from this sandbox until these are understood and measured:

1. `VoxelLodTerrain` block/LOD streaming around `VoxelViewer`.
2. Smooth SDF planet generation through `VoxelGeneratorGraph`.
3. Transvoxel meshing and LOD transitions.
4. Cave/ravine generation suitable for ship-scale tunnels.
5. Runtime edits/mining and local remeshing.
6. Material indices for geological resources.
7. SQLite persistence and unload/reload behavior.
8. Collision cost while flying quickly near cave walls.
9. Reference-body/origin shifting.
10. Limits of multiplayer support, especially that Voxel Tools 1.7 does not provide built-in `VoxelLodTerrain` multiplayer synchronization.

Read `docs/godot-skills/voxel-world-streaming/SKILL.md` before implementing experiments here.
