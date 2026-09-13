# Ship Power System Design — Cooperative Power Management

> Companion to `docs/SPACE_FLIGHT_CONTROL_DESIGN.md`. This note defines how stored/generated energy becomes usable ship power and how a second crew member can dynamically allocate that power among propulsion, shields, weapons and support systems.

## Core separation of responsibilities

The ship should not treat the battery, engine/powerplant and thrusters as the same system.

Conceptually:

```text
ENERGY SOURCE / STORAGE
battery, fuel, reactor fuel, exotic energy source
        |
        v
POWERPLANT / GENERATOR
converts the available source into usable ship power
        |
        v
POWER BUS / DISTRIBUTOR
allocates available output among ship systems
        |
        +--> PROPULSION
        |      -> vector thrusters / RCS / gyro actuators
        |
        +--> SHIELDS
        |
        +--> WEAPONS
        |
        +--> SENSORS / COMPUTERS
        |
        +--> LIFE SUPPORT / AUXILIARY
        |
        +--> COOLING / REPAIR / UTILITY (later)
```

The current prototype already has the beginning of this separation (`SolarBattery -> MainEngine -> thrusters`). The names may evolve as the architecture becomes more generic, but the separation should remain.

### Energy source is not permanently tied to a battery

Do not hardcode propulsion around `SolarBattery`.

Use a generic source/storage interface so later ships can use different technologies:

```text
EnergySource
├── battery pack
├── chemical fuel + generator
├── fusion fuel / reactor
├── solar + accumulator
└── exotic / late-game source
```

The source answers questions such as:

```text
stored_energy
available_discharge_rate
fuel/resource remaining
health
```

### Powerplant / engine

The powerplant consumes or draws from the energy source and produces a maximum usable output rate.

Possible properties:

```text
rated_output
current_output
efficiency
spool / response time
heat generation
health
fuel interface / accepted source type
```

This is where a more powerful crafted engine/powerplant changes the total power budget of the ship.

### Thrusters are actuators

Thrusters do not create unlimited energy. They transform the propulsion share of the power budget into physical force.

They are analogous to driven wheels/propulsors rather than the ship's energy source.

Each thruster still has its own limits:

```text
max_thrust
max_power_draw
gimbal envelope
response speed
efficiency
health
```

The actual maximum thrust at any instant is limited by both the thruster itself and the propulsion power currently assigned to the propulsion bus.

## Power distribution

Introduce a project-owned power distribution layer conceptually like:

```text
ShipPowerManager
├── available_power
├── propulsion_allocation
├── shields_allocation
├── weapons_allocation
├── systems_allocation
└── reserve / emergency rules
```

The engineering station manipulates allocation targets, while the manager enforces the real total budget.

Example:

```text
reactor output: 1000 units

PROPULSION   45% -> 450
SHIELDS      30% -> 300
WEAPONS      20% -> 200
AUXILIARY     5% ->  50
```

Allocation values are requests/priorities. If the powerplant is damaged and output drops to 600, every downstream system must react to the reduced real supply according to the chosen policy.

## Why this improves flight control

Power allocation should physically limit available propulsion rather than merely changing an artificial joystick sensitivity value.

If the engineer reduces propulsion from 100% to 20%, the same pilot command reaches the thruster allocator, but the propulsion bus caps the force that can actually be produced.

```text
pilot requests maximum translation
        |
        v
ThrusterAllocator requests 1800 N equivalent
        |
        v
propulsion bus has only 20% authority
        |
        v
thrusters receive reduced power
        |
        v
ship accelerates gently
```

This naturally creates a useful **precision maneuvering** state for caves, docking and interiors without introducing fake physics.

Conversely, engineering can temporarily divert most power to propulsion:

```text
PROPULSION 90%
SHIELDS     5%
WEAPONS     0%
AUXILIARY   5%
```

All four vector thrusters can then align and combine their force for a high-acceleration escape/burn, provided the powerplant and thrusters can handle it.

## Cooperative crew role — engineer / power officer

Power distribution should normally be a separate crew responsibility from piloting.

The pilot asks for motion. The engineer decides how much ship capability is available to satisfy that request.

```text
PILOT
sticks + triggers
    -> desired force / torque

ENGINEER
power panel
    -> propulsion / shield / weapon / auxiliary budgets

FLIGHT COMPUTER
combines both
    -> actuator commands constrained by available propulsion power
```

This creates meaningful communication between players:

- pilot: "give me more engines, I need to brake";
- gunner: "I need weapon charge";
- engineer: shifts power from shields to weapons;
- incoming attack: engineer dumps power into shields;
- entering a narrow cave: engineer reduces propulsion authority for fine control;
- emergency escape: shields/weapons are sacrificed for maximum thrust.

The goal is not a passive slider screen. Power management should create short tactical decisions that interact directly with what the other crew members are doing.

## Suggested initial power consumers

Start with a small set that has obvious gameplay consequences:

```text
1. PROPULSION
   vector thrusters / RCS / gyros

2. SHIELDS
   shield strength, recharge rate and possibly recovery delay

3. WEAPONS
   recharge / capacitor rate, sustained fire and eventually weapon intensity

4. AUXILIARY / SHIP SYSTEMS
   sensors, computers, lights, life support, doors, pumps, etc.
```

Later split auxiliary systems when they become deep enough to justify separate controls:

```text
SENSORS
LIFE SUPPORT
COOLING
REPAIR / FABRICATION
TRACTOR / MINING / INDUSTRIAL SYSTEMS
```

Cooling is especially useful as a second resource axis later: maximizing reactor output, weapons and propulsion can create heat even if enough energy is available.

## Weapons

Power should not simply multiply arbitrary damage every frame.

Prefer physically/readably affected weapon properties such as:

- capacitor recharge speed;
- maximum sustained fire;
- projectile launch energy for weapons designed to support variable charge;
- laser/plasma output;
- turret traverse/actuation where appropriate.

This allows an engineer to prepare a high-power shot without making every weapon's balance depend on one global damage multiplier.

## Shields

Power allocation may affect:

```text
maximum active shield output
recharge rate
recovery after collapse
resistance to sustained incoming damage
```

A shield under active fire may request more power than its normal idle allocation. The engineer can decide whether to satisfy that demand.

## Propulsion + A stabilizer + B vector brake

The flight assists still use real propulsion authority.

```text
A stabilizer
-> requests corrective torque
-> ThrusterAllocator / gyro actuators
-> consumes propulsion/control-system power

B vector brake
-> requests force opposite current velocity
-> ThrusterAllocator
-> consumes propulsion power
```

Therefore a ship with propulsion starved of power cannot magically stop or stabilize at full strength.

This is important for cooperative gameplay. An engineer who cuts propulsion too far while the pilot is trying to brake creates a real consequence.

The HUD should communicate when an assist is limited by insufficient power rather than making the controls appear broken.

## Power presets

To avoid turning engineering into constant micromanagement, support presets that can still be adjusted manually.

Examples:

```text
CRUISE
balanced power

COMBAT
shields + weapons priority

MANEUVER
reduced propulsion cap for precise movement

ESCAPE / FULL BURN
maximum propulsion

DEFENSE
maximum shields

SILENT / LOW POWER
minimal nonessential systems
```

An experienced engineer can override individual allocations after selecting a preset.

## Solo / missing crew fallback

The architecture must support multiple crew members without making a ship unusable when fewer players are present.

If no engineer is occupying the engineering station:

```text
default power-management computer
-> balanced preset
-> simple automatic demand handling
```

A human engineer can take control and outperform/change those defaults.

This pattern can later apply to other crew roles: automation is functional, specialized players provide better tactical control.

## Damage and construction dependency

Like propulsion, power management must ultimately depend on what was physically crafted.

A ship blueprint may contain:

```text
energy source(s)
powerplant(s)
power buses / conduits
shield generators
weapon capacitors
thrusters
cooling equipment
```

Damage can therefore cause partial system failures:

```text
reactor damaged
-> total output falls

power conduit destroyed
-> one subsystem loses supply

battery damaged
-> stored reserve falls / hazardous failure possible

shield generator damaged
-> shield cannot consume all allocated power

thruster destroyed
-> propulsion allocation remains available but that actuator cannot use it
```

This should integrate with the future voxel hull/internal exposure system: destroying armor can expose the actual power components and make targeted subsystem damage possible.

## Recommended implementation sequence

Do this after the first four-vector-thruster flight model is controllable enough to evaluate.

1. Keep `EnergySource`, `PowerPlant`, `PowerBus` and consumers as separate abstractions.
2. Generalize the current battery/engine connection so the source type can change later.
3. Introduce `ShipPowerManager` with a fixed total power budget.
4. Make propulsion allocation physically cap thruster output.
5. Add a simple engineering UI with propulsion/shields/weapons/auxiliary percentages.
6. Add power presets.
7. Add shield and weapon consumers as their gameplay prototypes appear.
8. Add heat/cooling only after energy allocation itself is proven fun.
9. Later make buses/components craftable and damageable.

The critical rule is that power management modifies the same physical/gameplay systems used normally; it should not be a separate collection of arbitrary buffs.
