# Space Flight Control Design — Vector Thruster Crafting

> Living design note for the cooperative modular spacecraft game. The goal is to make flying the spacecraft a skillful physical activity rather than a canned six-degree-of-freedom controller that ignores how the ship was built.

## Core principle

The spacecraft does **not** have guaranteed movement axes.

The player crafts a chassis and places propulsion/attitude components. The control system then tries to satisfy the pilot's requested motion using the thrusters that actually exist, at their actual mount positions, with their actual gimbal limits, thrust, power availability and damage state.

This follows the desirable Space Engineers-style principle:

```text
PLAYER INPUT
    -> requested force / requested torque
    -> flight computer / gyro controller
    -> thruster allocation
    -> individual nozzle directions + throttle
    -> real RigidBody3D forces at mount positions
```

A badly designed or damaged craft can therefore lose authority in one direction or rotation axis. A good design is part of the gameplay.

## Four-vector-thruster prototype

The next ship-control experiment should use the current four thruster mounts as four independently controllable vector thrusters rather than treating them as a conventional fixed engine set.

Each thruster has at least:

```text
mount_position
max_thrust
current_throttle
gimbal limits / reachable direction cone
power availability
health / functional state (later)
```

The important consequence is that the four thrusters can cooperate.

### Pure translation

When the pilot requests a translation and all four nozzles can reach the requested direction, the allocator should align them in approximately the same direction.

```text
T1 --->
T2 --->
T3 --->
T4 --->

net force = T1 + T2 + T3 + T4
net torque ~= 0
```

This gives maximum acceleration in that direction because thrust sums.

### Rotation

To rotate without excessive translation, the allocator should create opposing force couples using the real mount positions.

Examples conceptually:

```text
left side  ↑      right side ↓   -> roll couple
front      →      rear       ←   -> yaw/pitch couple depending geometry
```

The exact individual directions are solved from the desired torque and the available actuator geometry rather than hardcoded per named thruster.

### Mixed movement

The interesting case is simultaneous translation + rotation.

The allocator receives a desired wrench:

```text
DesiredWrench
├── linear_force_local : Vector3
└── angular_torque_local : Vector3
```

and distributes the request across all available thrusters.

This allows, for example:

- accelerate while yawing;
- strafe while rolling;
- move vertically while pitching;
- brake while rotating toward a target;
- align every thruster for a burst of maximum linear acceleration.

The control should have enough depth that ship handling is itself a small mastery game, while still providing stabilization assists so losing control is recoverable.

## Input philosophy

The desired prototype uses **two analog triggers + two analog sticks** as the primary flight controls.

The triggers provide thrust demand / propulsion authority while the sticks describe direction and rotation intent. The exact first mapping should be tuned experimentally rather than permanently hardcoded before testing.

Important rule: input should produce a **requested motion/wrench**, not direct knowledge of `FL`, `FR`, `RL`, `RR` in gameplay code. The thruster allocator owns individual actuator decisions.

This lets the same controls work later on a player-built ship with six, eight or twenty thrusters.

### Candidate control model for the first experiment

Use both triggers as independent analog thrust budgets which may be combined for full power, while both sticks produce translational/angular intent. The mixer is allowed to vector and differentially throttle all four nozzles.

The player should visibly feel that:

- squeezing one trigger gives partial/one-group authority;
- squeezing both allows the allocator to use maximum available propulsion;
- aligning the requested vectors permits all four thrusters to add their thrust;
- opposing/mixed stick requests consume some linear acceleration in exchange for torque.

The final ergonomic mapping should be chosen by play testing rather than by theory alone.

## Stabilizer — A button

`A` toggles the **attitude stabilizer**.

In zero gravity this must **not** try to find a global horizon. Its job is angular-rate control:

```text
pilot releases rotational input
        -> desired angular velocity approaches zero
        -> controller requests opposing torque
        -> thruster allocator / gyro produces that torque
        -> ship stops spinning
```

The current prototype behavior where angular velocity can grow until the ship becomes an uncontrollable top is unacceptable.

The stabilizer should strongly damp angular velocity while preserving deliberate pilot rotation. A useful model is:

```text
requested_angular_velocity = pilot angular input * max_rate
error = requested_angular_velocity - measured_angular_velocity
requested_torque = PD(error)
```

When the pilot releases the stick, requested angular velocity becomes zero and the craft actively kills spin.

### Craft dependency

The stabilizer is an assist, not magic.

Its requested torque should be executed through available control actuators:

- gimballed main thrusters;
- RCS / maneuvering thrusters;
- gyroscope module, if installed;
- combinations of the above.

If the ship is damaged or badly built, stabilization authority may be weaker on some axes.

## Vector brake / station hold — B button

`B` becomes a **3D vector brake / station-hold assist** in SPACE mode.

First stage:

```text
current linear velocity
        -> target velocity = Vector3.ZERO
        -> request force opposite velocity
        -> allocator vectors available thrusters
        -> ship decelerates to near zero
```

Once nearly stationary, the system can maintain the stopped state against small disturbances.

A later stronger `station hold` mode may also capture the current world position and apply a slow positional PID, useful near stations/asteroids. In pure zero-G, velocity hold alone is sufficient after the craft reaches zero velocity unless another force acts on it.

`B` should automatically cooperate with the A stabilizer so the craft can become both translationally and rotationally quiet.

## Thruster allocation architecture

Do not encode behavior as rules such as "rear thrusters always move forward".

Create a project-owned allocator, conceptually:

```text
FlightControlComputer
    -> DesiredWrench

ThrusterAllocator
    -> inspect all active ThrusterActuator instances
    -> solve/approximate force + torque allocation
    -> output ThrusterCommand[]

ThrusterActuator
    -> clamp requested vector to its real gimbal envelope
    -> apply throttle/power/health limits
    -> RigidBody3D.apply_force(force, mount_offset)
```

The first solver can be heuristic/iterative; it does not need a perfect optimization algorithm on day one. The architecture should allow replacement with a constrained least-squares/pseudoinverse solver later.

## Future crafted ships

Every installed propulsion component contributes an actuator description rather than being assumed by vehicle code.

```text
ThrusterActuatorDefinition
├── max_thrust
├── mount transform
├── gimbal cone / axes
├── response speed
├── power requirement
├── heat
└── health/state
```

The flight computer builds its control-authority model from the installed components.

This naturally creates meaningful construction tradeoffs:

- four thrusters pointing mostly aft -> fast forward, poor braking/strafe;
- omnidirectional RCS -> excellent maneuverability, extra mass/power;
- widely spaced thrusters -> greater torque leverage;
- centered thrusters -> efficient translation, weak rotation leverage;
- damaged left thruster -> asymmetric control;
- all four aligned -> maximum thrust burst.

## Relationship to flight modes

The project currently distinguishes SPACE and SURFACE/local-gravity contexts.

Near-term priority is SPACE mode:

```text
SPACE
- no global horizon
- six-degree-of-freedom force/torque intent
- A: angular stabilization
- B: vector brake / station hold
- crafted actuator authority
```

A gravity/atmospheric flight mode can be designed later and can use different assistance rules while sharing the same actuator/allocator foundation.

## Recommended implementation order

1. Refactor input into explicit translational and angular requests plus two analog trigger values.
2. Refactor each current thruster into a true actuator with a configurable reachable vector/gimbal envelope.
3. Introduce `DesiredWrench` + `ThrusterAllocator` independent from `VehicleLogic`.
4. Make pure translation align all usable thrusters so their thrust sums.
5. Make requested rotation generate force couples from real mount positions.
6. Fix A stabilization using angular-velocity target/damping through the same allocator.
7. Implement B vector brake using target linear velocity zero.
8. Tune stick/trigger mapping by play testing.
9. Only afterward add extra RCS/gyro actuators and player-crafted layouts.

The crucial design rule is that stabilization and braking use the **same physical actuator model** as normal flight. They are control assists, not hidden teleport/velocity hacks.
