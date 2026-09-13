# Skill — Voxel Worlds, Planetoids and Streaming

Use this skill before changing voxel terrain, planetoids, cave generation, large-world streaming, voxel persistence, voxel materials, or planet-scale loading in this repository.

## Project intent

The emerging game direction combines three important references:

- **No Man's Sky** — continuous travel between space and planetary environments, exploration, procedural worlds and broad sandbox structure.
- **Deep Rock Galactic** — large navigable cave networks, mining/salvage objectives, organic enemies, resource landmarks and excursions outside the vehicle.
- **Lovers in a Dangerous Spacetime-style cooperative ship roles** — several players share one craft and operate different systems such as piloting, engineering/power, weapons, repair and exploration.

The important project twist is that the **spacecraft itself should be able to enter very large caves**, mine, salvage and traverse underground spaces. Crew can leave the ship for specific objectives such as mining, recovery, rescue, repair, scouting or accessing spaces the ship cannot reach.

## Main conclusion

Do **not** continue scaling the current monolithic dense voxel array into a planet system.

For large destructible planetoids, the strongest existing foundation reviewed is **Zylann Voxel Tools 1.7** (`Zylann/godot_voxel`, MIT), specifically `VoxelLodTerrain` + `VoxelViewer` + `VoxelStream` + `VoxelGeneratorGraph` + `VoxelMesherTransvoxel`.

The current custom mesher remains valuable as a small proof and for understanding/editing voxel concepts, but it should not become a home-grown replacement for years of chunk streaming, LOD, persistence and threaded terrain infrastructure unless Voxel Tools fails a measured requirement.

## Versions reviewed

Voxel Tools:

- Repository: `https://github.com/Zylann/godot_voxel`
- Reviewed release: **v1.7**
- License: MIT
- Release includes a **Godot 4.7.2 stable custom build**.
- Voxel Tools also exists as a **GDExtension** usable with official Godot 4.4.1+ builds.

Solar-system reference demo:

- Repository: `https://github.com/Zylann/solar_system_demo`
- Pinned study commit: `7e6c95db11b6122ee44efc725fe284a84b1d2b08`
- License: MIT
- The demo README expects a Godot build containing the Voxel Tools module.

For our production project, evaluate the **GDExtension edition first** because it allows staying on official Godot/export templates. For studying the solar-system demo, using the supplied/custom Voxel Tools build is the simplest path.

## Core mental model

Voxel Tools separates five concerns that should also remain separate in our architecture:

```text
VoxelGenerator
    procedural base world, ideally reproducible from seed

VoxelBuffer / channels
    voxel data: SDF, material indices, type, color, custom data

VoxelMesher
    converts voxel data to visible/collision meshes

VoxelTerrain / VoxelLodTerrain
    chunk/block lifetime, threaded generation, remeshing, LOD

VoxelStream
    load/save modified blocks without holding the whole world in RAM
```

A `VoxelViewer` attached to the active camera/player tells terrain systems **where detail/data is required** and prioritizes nearby work.

Voxel Tools calls chunks **blocks**. Typical block dimensions are around 16³ voxels, but meshing block size can be configured.

## Why `VoxelLodTerrain` is the likely planet solution

`VoxelTerrain` uses a simple block grid and loads/unloads blocks as the viewer moves. It is good for Minecraft-like or moderate-size terrain.

`VoxelLodTerrain` uses multiple levels of detail and is intended for much larger view distances. It works with smooth SDF terrain and `VoxelMesherTransvoxel`, including transition meshes between LODs.

Our planetoids should therefore use approximately:

```text
planet procedural SDF
    -> VoxelGeneratorGraph
    -> VoxelLodTerrain
    -> VoxelMesherTransvoxel
    -> VoxelViewer(s)
    -> VoxelStreamSQLite for persistent edits
```

Do not render the planet as visible little cubes. The voxels are data samples; the visible surface should be a smooth/organic mesh extracted from an SDF. This is the important distinction that solves the "Minecraft" appearance while preserving editable volumetric terrain.

## Solar-system demo patterns worth reusing

The reviewed solar-system demo is unusually close to our target and should be studied before building equivalent infrastructure.

It demonstrates:

- procedural rocky planets and a moon;
- planets about 1–2 km radius, with an optional x10 scale mode;
- ground-to-space spacecraft travel;
- atmosphere and clouds as a separate visual system;
- `VoxelGeneratorGraph` sphere + terrain noise;
- ravines and deep caves generated volumetrically;
- one `VoxelStreamSQLite` save database per planet;
- `VoxelLodTerrain` for each rocky planet;
- `VoxelMesherTransvoxel` for smooth terrain;
- `VoxelInstancer` for props such as rocks and grass;
- persistent voxel edits;
- reference-body / origin shifting for large distances.

Representative setup used by the demo includes:

```text
VoxelLodTerrain
lod_count               ~= 7+
lod_distance            ~= 60
collision_lod_count     ~= 2
mesh_block_size         = 32
threaded_update_enabled = true
mesher                   = VoxelMesherTransvoxel
stream                   = VoxelStreamSQLite per planet
generator                = duplicated/configured VoxelGeneratorGraph
```

These are references, not values to copy blindly.

### Important demo caveat: `full_load_mode_enabled`

The demo sets `full_load_mode_enabled = true` with a comment that leaving it off enables data streaming but is slower.

For our genuinely large worlds, **do not assume this should stay enabled**. The whole point of our architecture is to let distant edited blocks unload from memory and persist through the stream. Benchmark both modes and default toward actual streaming for large planets.

## Planet representation tiers

A planet must never exist at full voxel resolution everywhere at once.

Use representation tiers:

```text
VERY FAR
  tiny proxy/impostor

SPACE / FAR ORBIT
  cheap low-detail spherical representation
  atmosphere visible as appropriate

NEAR ORBIT
  VoxelLodTerrain contributes low/medium LOD terrain

SURFACE / CAVES
  high-detail blocks around active viewers
  collision only where useful
  resources / props / enemies streamed by gameplay region

FAR SIDE OF PLANET
  no high-resolution blocks unless another player/viewer needs them
```

The atmosphere can visually hide the star field when the player descends, but **atmosphere is not streaming**. We must explicitly unload/demote distant space assets, terrain blocks, physics, AI, props and mission scenes.

## Atmosphere is a separate subsystem

The solar-system demo's atmosphere is not part of Voxel Tools. It is an additional shader/addon system.

Keep the architecture separated:

```text
PlanetTerrainController
  -> VoxelLodTerrain

PlanetAtmosphereController
  -> sky/scattering/clouds

PlanetContentStreamer
  -> props/enemies/missions/audio

PlanetGravityController
  -> local radial gravity
```

Our already-reviewed **Clouds for Little Planets** candidate may be used for selected planets, but should not be allowed to own terrain streaming or gameplay state.

## Smooth voxels and material data

For organic planets/caves, prefer smooth SDF terrain with `VoxelMesherTransvoxel`.

Voxel Tools can store material information volumetrically:

- `CHANNEL_SDF` — density/signed distance for terrain shape.
- `CHANNEL_INDICES` — material/texture indices for smooth terrain.
- `CHANNEL_WEIGHTS` — optional blended material weights.
- other/free channels may hold additional data if required.

### Material strategy

For the first practical planet proof, use **Single** texture index mode where every voxel has one 8-bit material index. This supports up to 256 material IDs and is much simpler than weighted blending.

The heavier `Mixel4` mode stores up to four blended textures per voxel, but is more complex and limited to 16 source textures. Only adopt it when smooth visual blending is a demonstrated requirement.

Our material definition remains project-owned:

```text
VoxelMaterialDefinition
  id
  visual texture/material mapping
  density / mass relevance
  hardness
  damage / penetration resistance
  mining value
  thermal/electrical properties later
  emission / special behavior
```

Use Voxel Tools channels as compact storage/render input, not as the sole gameplay definition database.

Geological families currently envisioned include:

- basalt / common rock;
- silicate / fractured stone;
- iron-rich rock;
- metallic ore;
- crystal / iridescent mineral;
- emissive mineral;
- ice / glassy material where appropriate.

Rare emissive deposits should serve as cave landmarks and resources, not uniformly light the cave.

## Cave generation for this game

Caves must be designed for the **ship scale**, not just a walking character.

Use a combination of:

1. procedural SDF/noise for organic variation;
2. explicit large chambers and guaranteed connections for navigability;
3. smaller branches intended for crew/EVA only;
4. resource veins and wreck/mission placement as semantic layers.

Desired hierarchy:

```text
SPACE ENTRANCE
  -> ship-scale tunnel
     -> major chamber
        -> branch chamber
        -> mining pocket
        -> wreck / objective
        -> narrow crew-only passage
```

A purely random noise cave generator is not sufficient because it can produce disconnected pockets or unreadable sponge terrain.

Deep Rock Galactic is the main cave/gameplay reference: readable chamber-to-tunnel rhythm, mining landmarks, hostile organic life, objectives underground and routes that feel discovered rather than like an arbitrary maze.

## Streaming beyond terrain

Voxel Tools streams terrain data and can instance terrain props, but it does **not** solve our full mission/gameplay streaming architecture.

Build a project-owned layer:

```text
PlanetRegion
  terrain state reference
  props/resources
  structures/wrecks
  enemies
  mission actors
  ambience/audio
  encounter state
```

`PlanetContentStreamer` loads nearby region content and unloads/pools distant scene nodes while durable logical state remains in a lightweight save/session model.

Enemy AI and mission nodes must not remain active merely because the planet exists.

## Origin shifting / reference body

Large space worlds quickly exceed comfortable single-precision coordinate ranges.

The solar-system demo addresses this by selecting a **reference body** and shifting the local frame when the player approaches another planet. Static bodies for the active reference are reparented/managed so local physics stays near origin.

For our project, keep this as an explicit architecture concern:

```text
absolute/celestial state
        -> high-level system coordinates

active local reference body
        -> Godot physics/render coordinates near origin
```

Do not let a huge solar system remain permanently represented as large Godot `Vector3` coordinates and assume Jolt/physics precision will remain stable.

The demo's x10 planet mode explicitly warns of physics issues, reinforcing that origin/reference strategy must be tested early.

## Performance rules

Voxel Tools is threaded, but several costs still hit the main thread.

### Do

- leave CPU headroom; do not allocate every hardware thread to voxel work;
- use the voxel main-thread time budget to spread uploads/work;
- prefer mesh block size 32 when draw-call/block count is too high, after measuring edit latency;
- use modest collision LOD counts;
- keep terrain viewers/view distances appropriate to actual gameplay;
- use built-in VoxelTool/graph/native operations for heavy work;
- profile fast ship movement near surfaces and tunnels.

### Avoid

- huge GDScript triple loops over voxel volumes in gameplay;
- one Godot node or collider per voxel;
- regenerating whole planets after local edits;
- enabling collision for distant LODs that cannot interact with gameplay;
- assuming high-speed flight through dense chunk boundaries is free.

### Known important cost

Godot/Vulkan can stall when many small terrain meshes are destroyed while moving quickly. Voxel Tools mitigates this, but recommends reducing block count, reducing LOD distance, or limiting near-terrain movement speed if needed.

Terrain collision creation is also relatively expensive and largely lands on the main thread. For our ship-in-caves gameplay, benchmark collision streaming early. Use only the collision radius/LOD actually needed for the ship and nearby crew.

## Moving ship hull versus static terrain

Do not use `VoxelLodTerrain` as the spacecraft's authoritative moving body.

Voxel terrain physics is fundamentally oriented toward static terrain. Moving terrain is possible but physics correctness on a moving surface is not the intended use.

Keep the earlier split:

```text
PLANETOIDS / ASTEROID TERRAIN
  -> Voxel Tools terrain system

PLAYER / ENEMY SPACECRAFT
  -> project-owned RigidBody3D + Jolt
  -> project-owned voxel hull/collision compiler or separately validated destruction backend
```

The same conceptual material catalog can be shared, but moving ship voxel architecture and static world terrain do not need the same runtime node type.

## Persistence

Use `VoxelStreamSQLite` as the first persistence candidate for planet edits.

Important behavior:

- terrain data is requested block-by-block;
- only nearby blocks need to be memory-resident;
- modified blocks can save asynchronously;
- unloading a modified block triggers saving;
- explicit `save_modified_blocks()` can be used on save/quit checkpoints;
- stream resources should be created per save/session/planet rather than embedding and mutating one cached stream resource inside a reusable scene;
- do not kill the process while asynchronous saves are pending if persistence matters.

A natural project structure is one stream/database per persistent planet or world instance.

## Multiplayer caveat — critical

As of Voxel Tools 1.7 documentation, built-in multiplayer synchronization exists experimentally for **`VoxelTerrain`**, but **`VoxelLodTerrain` does not have built-in multiplayer support**.

Therefore our planet-scale multiplayer architecture must remain project-owned.

Recommended direction:

```text
HOST
  authoritative planet seed/version
  authoritative voxel edits
  authoritative persistent changed blocks

CLIENT
  generate unchanged terrain locally from same generator/seed
  receive semantic edits or changed block/diff data
  rebuild local VoxelLodTerrain state
```

For lightweight edits, replicate operations such as:

```text
DIG_SPHERE(position, radius, tool/material rules, operation_id)
MINE_VOLUME(...)
PLACE_MATERIAL(...)
```

For late join or heavily modified regions, send compact changed block state/diffs rather than replaying every historical impact forever.

Do not assume LinkUx or Voxel Tools will solve this automatically. Keep terrain networking behind our `NetworkService` / planet replication layer.

## Multiple players / viewers

Voxel Tools supports `VoxelViewer` concepts and the server-side multiplayer notes describe viewers for remote players in `VoxelTerrain`.

For local/planet streaming design, think in terms of a **union of required regions around active players**. If two players are far apart on the same planet, the server may need terrain data around both while each client normally needs detailed visuals only around its local player.

This has direct performance consequences and should be tested before promising very large player counts spread across a planet.

## Current recommended implementation order

1. Keep current handcrafted cavern prototype as comparison/reference.
2. Study/run the pinned `solar_system_demo` separately.
3. Test Voxel Tools 1.7 with Godot 4.7.2.
4. Prove one spherical `VoxelLodTerrain` with:
   - organic smooth surface;
   - ship-scale caves;
   - multiple material indices;
   - radial gravity;
   - atmosphere as a separate system;
   - viewer-driven LOD/streaming.
5. Prove runtime mining/digging with local remesh and persistent SQLite edits.
6. Measure fast spacecraft traversal and collision streaming.
7. Only then decide whether the project's planetoids migrate to Voxel Tools.
8. Keep spacecraft crafting/destruction as a separate moving-body voxel problem.
9. Design custom host-authoritative planet-edit replication before multiplayer implementation.

## Proof checklist before adoption

Do not adopt Voxel Tools into the production prototype merely because the demo looks good.

Prove:

- Godot 4.7.2 compatibility on our Windows target;
- GDExtension versus module tradeoff;
- spherical terrain at our desired radius;
- ground-to-space visual continuity;
- ship-scale caves with no LOD holes/cracks;
- stable Jolt collision while the ship moves through caves;
- runtime editing/mining;
- multiple geological materials;
- emissive resource landmarks;
- unload/reload of edited regions with persistence intact;
- memory behavior when crossing a planet;
- performance while moving quickly near terrain;
- at least two separated viewer regions for future multiplayer planning;
- clean export path for the chosen Voxel Tools edition.

## Sources to re-read only when exact details are needed

The conclusions above are intended to avoid repeating the full research. For exact APIs or version-sensitive behavior, consult:

- `Zylann/godot_voxel` v1.7 `doc/source/overview.md`
- `doc/source/smooth_terrain.md`
- `doc/source/streams.md`
- `doc/source/performance.md`
- `doc/source/multiplayer.md`
- `doc/source/getting_the_module.md`
- `Zylann/solar_system_demo` pinned commit `7e6c95db11b6122ee44efc725fe284a84b1d2b08`
- especially `solar_system/solar_system_setup.gd` and `solar_system/solar_system.gd`

Read this skill first. Re-open upstream only for precise API signatures, unresolved edge cases, or if the dependency version changes.