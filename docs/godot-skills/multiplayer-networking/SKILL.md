---
name: godot-multiplayer-networking
description: Project-specific Godot 4.7 multiplayer rules for authoritative ship physics, ENet/Steam transport, replication, interpolation, late join, crafting events and dedicated/listen-server architecture.
---

# Godot multiplayer networking

Use this skill when adding multiplayer sessions, replication, authority, network spawning, state synchronization, Steam/LAN transport, late join, dedicated servers, multiplayer crafting, or networked ship physics.

This project currently targets Godot 4.7.x, Forward+, Jolt Physics, typed GDScript, and a physics-driven modular spacecraft. Exact Godot 4.7 stable documentation remains authoritative for RPC and MultiplayerAPI behavior.

## Current architectural decision

For the current prototype, prefer a **host-authoritative simulation** for spacecraft and other important physics objects.

Conceptual flow:

```text
client input
    ↓
NetworkService
    ↓
host
    ↓
VehicleLogic + Jolt physics
    ↓
authoritative ship snapshot
    ↓
remote clients
    ↓
interpolation
```

Clients send commands/intent, not final ship transforms.

Examples of client input messages:

```text
throttle
yaw
pitch
roll
stabilizer toggle
weapon fire
construction request
```

Examples of host-authored state:

```text
position
orientation
linear velocity
angular velocity
flight mode
damage
energy/fuel
module changes accepted by the host
```

Do not rely on identical Jolt simulation on every peer.

## Plugin evaluation

### LinkUx

Reviewed source: `IUXGames/LinkUx`, MIT, LinkUx 2.x.

Strengths for this project:

- Godot-native GDScript addon.
- backend abstraction over ENet and Steam;
- session creation/joining;
- player lifecycle and authority;
- entity registration;
- replicated spawning and late-join replay;
- property replication with optional interpolation;
- delta compression;
- configurable network ticks;
- Steam backend through GodotSteam / SteamMultiplayerPeer;
- can support the same gameplay layer over LAN while developing and Steam later.

Useful source details:

- `StateReplicator` only emits state from the configured authority peer.
- replication supports `ALWAYS`, `ON_CHANGE`, and manual modes.
- late join can receive full snapshots plus spawn replay.
- default network config uses a 20 Hz tick rate, 100 ms interpolation delay, delta compression and batching.

#### LinkUx caveats for this project

Do **not** adopt `LinkUxSynchronizer` blindly for six-degree-of-freedom spacecraft rotation.

Its current interpolation handles `Vector3 rotation` axis-by-axis with `lerp_angle`. That avoids the ±π wrap problem but is still Euler interpolation. A spacecraft can freely pitch, yaw and roll, so our implementation should instead use quaternion/Basis/Transform3D interpolation with shortest-path quaternion `slerp`.

Recommended project adaptation:

```text
LinkUx transport/session/spawn layer
        ↓
our NetworkService wrapper
        ↓
our ShipSnapshotInterpolator
        ↓
Vehicle remote visual/proxy
```

Do not couple `VehicleLogic` directly to LinkUx APIs.

Also validate incoming authority before mutating authoritative state. LinkUx's current state receive path checks whether the local peer itself owns an entity, while host relay checks `from_peer == authority_peer` later. For production code, validate the sender against the entity authority **before applying received state**, especially for any client-owned replicated entity.

For this project, keeping important physics host-owned avoids much of this risk.

### netfox

Reviewed source/docs: `foxssake/netfox`, MIT.

netfox is a mature toolkit for network timing, interpolation, client-side prediction, reconciliation, rollback, visibility filtering, simulated network conditions, and lag compensation.

It is attractive for action games and contains excellent patterns worth learning.

However, full RigidBody physics rollback is **not a drop-in match for our present Jolt setup**. netfox documentation states that rollback physics requires manual physics stepping. Standard Godot releases do not currently expose the needed stepping path for ordinary RigidBodies, so their documented solutions use a custom Godot build/fork, Rapier, Blazium, or another stepping-capable physics integration.

Therefore:

- do not replace Jolt merely to adopt rollback during this prototype;
- do not introduce Netfox physics rollback until latency tests prove simple host-authoritative snapshot/interpolation is insufficient;
- Netfox remains an excellent reference for interpolation, input buffering, reconciliation, visibility filtering, network-condition simulation and future competitive/high-latency work.

### Godot 3D Multiplayer Template

Reviewed source: `devmoreir4/godot-3d-multiplayer-template`, MIT, Godot 4.7.

Use it as a **reference implementation**, not as our architecture.

Good patterns to absorb:

- simple ENet host/join flow;
- headless dedicated-server startup;
- local multi-instance testing;
- validation/sanitization of data received from clients;
- server-authoritative inventory/state changes;
- synchronized equipment/world items;
- practical UI/session flow.

Important mismatch:

Its player movement is client-authoritative: the player's node sets multiplayer authority to that peer and only the owning client runs its movement `_physics_process`. That is reasonable for its starter character controller but is not the architecture we want for our physics-driven ship.

## Recommended stack for the prototype

Current preferred approach:

```text
Gameplay
    ↓
NetworkService                 ← our stable API
    ↓
LinkUx                         ← candidate session/transport/replication infrastructure
    ├── ENet during development/LAN
    └── Steam backend later
         ↓
GodotSteam / SteamMultiplayerPeer
```

For spacecraft state, prefer our own explicit authoritative snapshot format and interpolation rather than generic property synchronization.

If LinkUx proves unnecessary or too invasive, `NetworkService` must make it possible to replace LinkUx with native Godot MultiplayerAPI + ENet/SteamMultiplayerPeer without changing gameplay code.

## NetworkService boundary

Gameplay code should call our abstraction, not a third-party plugin directly.

Conceptual API:

```gdscript
host_game()
join_game(code_or_address)
leave_game()
send_ship_input(input_frame)
request_build_module(command)
request_remove_module(command)
spawn_network_entity(definition)
get_local_peer_id()
is_host()
```

Network callbacks should translate packets/events into domain-level commands.

Do not scatter raw `rpc()`, `rpc_id()`, LinkUx singleton calls, Steam APIs, or ENet setup throughout gameplay classes.

## Ship physics replication

### Host

The host owns the ship `RigidBody3D` simulation:

1. collect player/operator input;
2. validate authority/seat ownership;
3. run thrusters/stabilizer/Jolt simulation;
4. periodically publish a compact ship snapshot.

Suggested snapshot:

```text
sequence/tick
time
position
orientation quaternion
linear_velocity
angular_velocity
flight_mode
optional discrete status bits
```

Avoid serializing every thruster transform every network tick. Thruster visuals can normally be reconstructed from accepted inputs/state locally.

### Remote client

Remote clients should not feed received state into a second competing ship simulation.

Prefer a remote representation/proxy that:

- buffers snapshots;
- renders slightly behind authoritative time;
- interpolates position;
- quaternion-slerps orientation;
- interpolates velocity where useful;
- snaps/corrects only when the prediction/interpolation error exceeds a deliberate threshold.

For a locally controlled ship, start with host authority and no prediction. Add client prediction only if measured latency makes controls unacceptable.

## Quaternion rule

For unrestricted spacecraft rotation, network orientation as `Quaternion` (or compact quaternion representation), not Euler angles.

Never interpolate free-flight orientation with `Vector3.lerp()`.

Use shortest-path quaternion interpolation (`slerp`) for rendered remote motion.

## Crafting / ship construction replication

Do not transmit merged mesh geometry.

The network source of truth is the ship blueprint/module graph.

Send discrete commands/events such as:

```text
ADD_MODULE(module_type, socket_id, local_transform)
REMOVE_MODULE(module_instance_id)
ROTATE_MODULE(module_instance_id, rotation)
SET_MODULE_CONFIG(module_instance_id, config_delta)
```

Host validates:

- player permission;
- available resources;
- socket compatibility;
- overlap/build rules;
- module limits;
- resulting ship validity.

After acceptance, broadcast the authoritative blueprint change.

Each peer then:

1. updates its local blueprint;
2. rebuilds only the affected visual chunk;
3. updates local component metadata;
4. host rebuilds authoritative collision/mass/center-of-mass as needed.

This keeps bandwidth low even when the final ship mesh contains hundreds of source parts.

## Reliable vs unreliable data

Prefer reliable delivery for:

- joining/session metadata;
- spawning/despawning;
- blueprint/crafting changes;
- inventory/resource changes;
- ownership/seat changes;
- important one-off actions.

Prefer unreliable/ordered or state-style updates for rapidly superseded data:

- ship snapshots;
- aim direction;
- transient analog input;
- cosmetic motion state.

Do not put all traffic on a single reliable channel; packet loss can then stall newer realtime state behind old packets.

## Late join

Late join must reconstruct authoritative durable state before realtime updates become meaningful.

Order conceptually:

```text
session/world metadata
→ durable entities
→ ship blueprints/modules
→ inventory/ownership
→ current physics snapshots
→ realtime stream
```

A late joiner should build the ship from blueprint data, not receive an arbitrary generated ArrayMesh blob.

LinkUx's spawn replay/full snapshot system is useful here but our world-state format should remain explicit and serializable independent of LinkUx.

## Dedicated server and listen server

Support both through the same domain logic where practical.

Prototype:

- listen server is acceptable for quick co-op testing;
- headless ENet dedicated server should remain possible;
- Steam listen-server/P2P can be added later.

Never assume the host always has a camera, UI, local player, or graphics device in shared gameplay/network code.

## Interest management / large space world

Do not replicate every asteroid or object to every peer every tick.

Static procedural asteroids can be reconstructed from shared world seed/settings where safe.

Replicate only dynamic/durable changes, for example:

- mined/destroyed asteroid state;
- player ships;
- constructed stations;
- cargo/items;
- nearby combat entities.

Use distance/sector relevance for frequent state updates.

A player in sector A should not receive 20 Hz transforms for ships thousands of kilometers away unless gameplay requires it.

## Security and validation

Treat every client request as untrusted.

Server/host should derive sender identity from the multiplayer API (`get_remote_sender_id()` or equivalent), not from a peer ID supplied inside the packet.

Validate before mutation:

- requested entity belongs to/accepts commands from sender;
- build request is legal;
- inventory quantities exist;
- cooldown/rate limits;
- requested values are bounded;
- sender is allowed to use the requested seat/control/component.

Do not accept client-authored final position, resources, damage or crafting results for host-authoritative systems.

## Testing matrix

Minimum networking proof loop:

1. two local instances over ENet;
2. host controls ship, remote observes smooth motion;
3. remote client controls assigned seat/input path;
4. artificial latency and packet loss;
5. disconnect/reconnect;
6. late join after ship has been modified;
7. host quits / expected failure behavior;
8. headless server path;
9. eventually Steam peer path.

Measure:

- RTT;
- packet rate;
- bytes/sec;
- snapshot buffer depth;
- interpolation error;
- correction frequency;
- server physics cost.

A clean parser/import run is not network proof.

## Source basis

Reviewed September 2026:

- `IUXGames/LinkUx` source, especially `StateReplicator`, `LinkUxSynchronizer`, `LinkUxSpawner`, backend abstractions and network config;
- `foxssake/netfox` current documentation/releases, including rollback physics requirements;
- `devmoreir4/godot-3d-multiplayer-template` Godot 4.7 source, especially ENet session handling and authority patterns;
- Godot 4.7 high-level multiplayer/RPC authority semantics.

Re-evaluate plugin versions before integrating because networking addons evolve quickly.
