# Game Vision — Cooperative Space Mining, Salvage and Exploration

> High-level direction for the game that is emerging from the current spacecraft, voxel-world and multiplayer experiments. Detailed spacecraft construction remains in `GAME_DESIGN.md`; implementation sequencing remains in `GAME_IMPLEMENTATION_ROADMAP.md`.

## Core fantasy

A small crew operates one highly customizable spacecraft together and explores a broad procedural space sandbox.

The strongest reference blend is:

- **No Man's Sky** — space-to-planet exploration, procedural destinations, broad sandbox traversal and discovery.
- **Deep Rock Galactic** — readable cave networks, mining objectives, valuable resource deposits, dangerous organic enemies, underground mission structure and the feeling of going somewhere hostile to bring something back.
- **Lovers in a Dangerous Spacetime-style shared-ship cooperation** — multiple players operate different systems of the same craft rather than each player always flying a separate vehicle.

This is inspiration, not a plan to copy those games' mechanics or art direction.

## Main differentiator

The **spacecraft itself can enter enormous cave systems**.

The ship is not only transportation between missions. It is the crew's mobile base, mining platform, combat vehicle, cargo carrier and survival space.

A mission may therefore flow continuously:

```text
SPACE
  -> find target body / distress signal / contract
  -> approach planetoid
  -> descend through atmosphere or enter asteroid opening
  -> locate a ship-scale cave entrance

UNDERGROUND SHIP PHASE
  -> navigate large tunnels and chambers
  -> illuminate darkness with ship lights
  -> mine large deposits with ship equipment
  -> fight cave creatures / automated defenses
  -> carry salvage and cargo
  -> manage damage, power and maneuvering in confined spaces

CREW EXCURSION
  -> land / anchor / hold position
  -> one or more crew leave the ship
  -> enter narrow passages or structures
  -> recover an objective / repair / rescue / scout / mine by hand
  -> return to ship

EXTRACTION
  -> escape cave / hostile area
  -> return to station / buyer / next destination
```

## Ship-scale versus crew-scale spaces

World generation should deliberately create both scales.

### Ship-scale

- very large cave entrances;
- broad tunnels;
- large chambers;
- mining caverns;
- wreck fields;
- underground bases;
- combat arenas;
- routes where vector-thruster piloting is challenging but practical.

### Crew-scale

- cracks and narrow tunnels;
- interiors of wrecks;
- stations/outposts;
- maintenance passages;
- sealed bunkers;
- resource pockets inaccessible to the ship;
- rescue locations.

The distinction creates a reason to leave the ship without turning the game into a conventional on-foot game most of the time.

## Mission families

The sandbox should support reusable mission archetypes that combine procedural terrain, ship operation and crew excursions.

### Mining

Locate and extract a required mineral/resource quantity.

Possible variations:

- common bulk ore with ship mining tools;
- rare crystal deposits deep in caves;
- fragile material requiring careful extraction;
- hot/radioactive/volatile deposits requiring engineering decisions;
- deposits defended by cave fauna.

### Salvage / scrapyard work

Locate wreckage, abandoned stations, crashed ships or industrial debris and recover valuable components/materials.

The ship may need to:

- cut through wreck sections;
- tow or carry large objects;
- load cargo physically;
- power an abandoned mechanism;
- expose an access route.

Crew may then enter the wreck for small/high-value items or data.

### Recovery

Find a specific lost object:

- black box;
- research sample;
- artifact;
- cargo container;
- navigation core;
- rare component.

The object may be buried, inside a wreck, carried by an enemy, or behind a narrow crew-only route.

### Rescue

Locate and extract:

- stranded miners;
- another crew;
- escape-pod survivors;
- disabled ship crew;
- trapped researchers.

This provides objectives where destroying everything is not the solution.

### Repair / restart

Reach a disabled installation or ship and restore a system while defending the area.

Potential tasks:

- replace power component;
- reconnect a generator;
- restart atmosphere/life support;
- repair a communications relay;
- tow a damaged craft out.

### Hunt / extermination

Organic cave enemies can create Deep-Rock-like pressure without defining the entire game around combat.

Examples:

- destroy a nest;
- hunt a large creature;
- survive while mining/extracting;
- clear a route for another operation.

### Survey / exploration

Find and scan unusual geological or artificial features, map a cave route, deploy sensors or reach a difficult location.

This is a good use of the ship's difficult-to-master vector movement without requiring combat.

## Enemies

The game can mix enemy categories by environment:

```text
CAVES / PLANETOIDS
  organic creatures
  burrowing/swarming enemies
  territorial large creatures

SPACE
  hostile ships
  pirates
  drones

RUINS / INDUSTRIAL SITES
  automated defenses
  security robots
  turrets
```

Organic cave enemies are especially useful because they contrast with the mechanical ship and can navigate terrain differently from vehicles.

## Mining from the ship

The ship should eventually support dedicated mining equipment rather than requiring crew to leave for every resource.

Possible modules:

- mining laser;
- cutting beam;
- drilling head / focused excavation tool;
- tractor/cargo collector;
- scanner for deposits;
- deployable lights or probes.

Large deposits are ship gameplay. Small or protected deposits can motivate crew excursions.

## Cooperative roles

The shared spacecraft should reward division of responsibility.

Possible stations/roles:

- pilot / navigation;
- engineer / power allocation / repairs;
- gunner;
- mining operator;
- sensors / scanner / mission navigation;
- cargo / salvage handling;
- crew member on excursion.

Roles should overlap enough that the game still works with fewer players. AI/automation or station switching can fill missing roles.

## World structure

The universe should feel broad without requiring every destination to remain loaded.

```text
STAR SYSTEM / SPACE
  cheap distant representations
        |
        v
PLANET / PLANETOID DOMAIN
  atmosphere + local gravity + terrain streaming
        |
        v
REGION / CAVE
  high-detail voxel terrain + props + enemies + mission state
```

Only the areas required by current players need full terrain, collision, props and AI.

See `docs/godot-skills/voxel-world-streaming/SKILL.md` for the researched Voxel Tools architecture and its multiplayer caveats.

## Design principle

The desired loop is not simply "fly to a planet, get out, play a walking game."

The ship should remain central:

> **Exploration, piloting, mining, combat, engineering, physical damage, cargo and crew excursions should all revolve around operating and protecting one persistent craft.**

Leaving the ship is important because some objectives cannot be solved by the ship, not because the ship stops being the main character of the game.