---
name: godot-lighting-environments
description: Project-specific Godot 4.7 lighting, environment, reflection, exposure, fog and post-processing guidance for space, asteroid, planetary and interior scenes.
---

# Godot lighting and environments

Use this skill when changing `WorldEnvironment`, skies, sun/moon lighting, exposure, GI, reflections, fog, glow, SSAO/SSIL/SSR, or lighting profiles in General Godot experiments.

This skill complements the vendored GodotPrompter material, especially:

- `upstream/GodotPrompter/skills/3d-essentials/SKILL.md`
- `upstream/GodotPrompter/skills/3d-essentials/references/environment-and-post.md`
- the exact stable Godot 4.7 documentation for version-sensitive properties.

## Core rule: lighting is a system, not a magic preset

Do not blindly import a single "realistic light" scene into every environment.

Separate the reusable ideas from scene-specific values. The project should own a lighting/environment controller and a set of profiles suited to each context.

Recommended conceptual architecture:

```text
LightingEnvironmentController
├── SPACE
├── ASTEROID_SURFACE
├── PLANET_ATMOSPHERE
├── INTERIOR
└── STATION
```

Each profile may control:

- `Environment`
- `Sky` / sky material
- `CameraAttributes`
- dominant `DirectionalLight3D`
- local Omni/Spot lights
- reflection probes
- GI mode
- fog/volumetrics
- exposure
- tone mapping
- screen-space effects
- quality tier

Prefer profiles/resources over hard-coded scene-wide constants.

## Lessons from Instant Realistic Light

Reviewed source:

- Godot Asset Library asset 2553, **Instant Realistic Light**
- upstream repository: `soykhaler/Instant-Realistic-Light-Godot-Engine`
- license: MIT

The addon itself is intentionally simple: its editor plugin instantiates a preconfigured lighting scene. The useful knowledge is the composition of that scene, not the plugin wrapper.

Its preset combines:

```text
PhysicalSkyMaterial
      ↓
Sky
      ↓
WorldEnvironment
├── tonemapping
├── SSAO
├── SDFGI
├── glow/bloom
├── volumetric fog
├── exposure / auto exposure
└── saturation adjustment

DirectionalLight3D
ReflectionProbe
CameraAttributesPractical
```

This is a useful checklist for a polished Forward+ scene, but the exact values are not universal defaults.

### Important interpretation

The source preset uses aggressive values such as a very high sky/background intensity, SDFGI, volumetric fog, glow, auto exposure, and a very large `ReflectionProbe`.

Treat those as an artistic preset for a bounded scene. Do **not** apply them globally to open space.

## Project profiles

### SPACE

Goals: readable silhouettes, deep blacks without crushed materials, stars remain visible, metallic craft still receives plausible highlights.

Recommended starting strategy:

- very dark sky/background;
- one physically coherent distant `DirectionalLight3D` for the local star/sun;
- ACES or AgX tonemapping, chosen after testing emissive colors;
- modest ambient/radiance contribution;
- SSAO/SSIL only where they produce a visible benefit;
- no global volumetric fog in vacuum;
- no expensive GI merely to illuminate empty space;
- reflection probes only around relevant local content, not one enormous always-updating probe;
- emissive engine/plasma materials may use glow sparingly.

### ASTEROID_SURFACE

Goals: strong shape definition, readable crevices, believable rock, dramatic sun/shadow contrast.

Recommended starting strategy:

- directional star light with shadows;
- SSAO for contact/crevice definition;
- SSIL if useful and affordable;
- rock materials should remain opaque and physically plausible;
- local reflection/environment contribution kept subtle for rough stone;
- avoid fog unless the asteroid has dust/gas for an explicit gameplay/art reason.

### PLANET_ATMOSPHERE

Goals: transition from space to atmosphere without a disconnected visual mode switch.

Recommended starting strategy:

- atmosphere/cloud system may own or cooperate with the active `WorldEnvironment` compositor;
- physical sky/atmospheric scattering where appropriate;
- auto exposure can help with space-to-ground dynamic range, but tune its adaptation speed and min/max sensitivity;
- volumetrics belong here, not in generic vacuum;
- quality must scale by distance and hardware;
- coordinate atmosphere effects with the dominant star direction.

When `Clouds for Little Planets` is adopted, integrate it through the lighting/environment controller rather than allowing it to become a second independent global environment system.

### INTERIOR / STATION

Goals: readable local lighting, convincing metals/plastics/ceramics, controlled performance.

Recommended starting strategy:

- local OmniLight3D/SpotLight3D fixtures;
- `ReflectionProbe` volumes for metallic/specular response;
- SSR where useful for on-screen reflective surfaces;
- choose SDFGI/VoxelGI only when dynamic indirect lighting justifies its cost;
- otherwise fake indirect lighting with carefully placed fill lights and probes;
- use emissive fixtures plus restrained glow, not bloom as a substitute for actual lighting.

## ReflectionProbe rules

Reflection probes are especially valuable for spacecraft, stations, metallic structures and interiors.

Prefer:

- spatially bounded probes;
- `UPDATE_ONCE` for mostly static environments;
- updates only when the reflected environment meaningfully changes;
- multiple local probes over one huge high-cost probe when that improves locality and quality.

Do not assume a huge probe is free just because the source preset used one.

## Global illumination selection

Choose GI intentionally.

### SDFGI

Use when:

- Forward+ is available;
- the scene benefits from dynamic large-scale indirect lighting;
- its GPU cost has been measured and accepted.

Avoid enabling it automatically for a huge sparse procedural space world.

### VoxelGI

Consider for bounded 3D spaces where a baked/static voxel volume is appropriate.

### Fake GI

For procedural or performance-sensitive worlds, prefer:

- ambient/radiance from sky/environment;
- fill lights;
- local reflection probes;
- emissive materials;
- SSAO/SSIL;
- authored local light rigs.

Measure the visual gain before paying for full GI.

## Exposure and tonemapping

Lighting and exposure must be tuned together.

Relevant options:

- ACES: strong photographic/filmic response, can alter saturated highlights.
- AgX: useful when preserving hue in bright emissive materials matters.
- auto exposure: useful for extreme dynamic range, especially space ↔ atmosphere/interior transitions.

Do not use auto exposure to hide incorrect light energy. First make the physical/artistic light ratios sensible, then use exposure to manage viewing adaptation.

For a chase-camera spacecraft game, avoid very slow adaptation that makes entering/leaving shadow feel like a broken display.

## Glow / bloom

Glow is a post effect, not a light source.

Use it for:

- engines;
- plasma/exhaust;
- bright displays;
- stars/suns;
- selected emissive fixtures.

Do not enable strong global bloom merely to make dim materials look lit.

Godot 4.6+ applies glow before tonemapping, so retest glow values when comparing older examples or presets.

## Fog and volumetrics

Volumetric fog is contextual.

Use for:

- atmosphere;
- dust;
- smoke;
- nebula-like authored volumes;
- interiors with a deliberate volumetric-light look.

Avoid in clean vacuum.

Keep volumetric range/density only as high as needed and profile GPU cost.

## Performance rules for large worlds

For the current asteroid/space prototype:

1. Do not make every asteroid own expensive environment effects.
2. Keep one active high-quality local lighting context around the player.
3. Use cheap far representations and LOD/HLOD.
4. Activate expensive atmospheric/volumetric effects only for the relevant nearby planetoid.
5. Prefer local reflection/GI volumes around stations/interiors.
6. Profile Forward+ effects independently: SSAO, SSIL, SSR, SDFGI, volumetrics and glow are separate costs.
7. Do not judge performance from editor FPS alone; test the running build and representative camera positions.

## Implementation pattern

Prefer a controller that applies a profile instead of scattering environment mutations across gameplay code.

Conceptual example:

```gdscript
class_name LightingEnvironmentController
extends Node

func apply_profile(profile: LightingProfile) -> void:
    apply_environment(profile)
    apply_camera_attributes(profile)
    apply_primary_light(profile)
    apply_reflection_strategy(profile)
    apply_quality_tier(profile)
```

Gameplay/world code should request a lighting context, for example:

```text
space_world -> SPACE
near atmosphere -> PLANET_ATMOSPHERE
enter station -> INTERIOR
land on airless asteroid -> ASTEROID_SURFACE
```

The controller owns the Godot-specific side effects.

## Validation checklist

When lighting changes, verify visually from multiple viewpoints and distances:

- front/back-lit spacecraft;
- sunlit and shadowed asteroid sides;
- metallic reflections;
- exposure entering/leaving shadow;
- glow around engines against black space;
- atmosphere viewed from orbit and near the surface;
- interior ↔ exterior transitions;
- no fog leaking into vacuum;
- no giant reflection/GI volume doing unnecessary work.

Also validate the exact target Godot version. A successful import/parser pass is not proof that the lighting looks correct.

## Source basis

This project-specific skill synthesizes:

- the reviewed source of **Instant Realistic Light** (Asset Library 2553 / `soykhaler/Instant-Realistic-Light-Godot-Engine`), especially its `light_scene.tscn` composition;
- the vendored GodotPrompter `3d-essentials` environment/post-processing reference;
- the project requirement for a large procedural space world with asteroid surfaces, spacecraft, future planetoids and interiors.

Official stable Godot 4.7 documentation remains authoritative for exact API behavior and renderer support.
