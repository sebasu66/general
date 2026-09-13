class_name VehicleLogic
extends RigidBody3D

@export_group("Attitude Stabilizer")
@export_range(0.0, 1.0, 0.01) var stabilization_mix: float = 0.96
@export var stabilization_kp: float = 5.6
@export var stabilization_kd: float = 2.1
@export var yaw_damping: float = 0.72
@export var max_yaw_correction: float = 0.52
@export_range(0.0, 0.7, 0.01) var max_stabilization_throttle: float = 0.48
@export_range(5.0, 45.0, 1.0) var soft_tilt_limit_degrees: float = 22.0
@export_range(15.0, 70.0, 1.0) var hard_tilt_limit_degrees: float = 42.0
@export_range(1.0, 4.0, 0.1) var anti_flip_gain: float = 2.2

@export_group("Hover Hold")
@export var hover_kp: float = 0.12
@export var hover_kd: float = 0.09
@export_range(0.05, 0.5, 0.01) var hover_max_correction: float = 0.32

var _thruster_nodes: Array[ThrusterLogic] = []
var _mount_ids: Array[StringName] = []
var _mount_positions: Array[Vector3] = []
var _max_thrusts: Array[float] = []
var _max_gimbals: Array[float] = []
var _latest_commands: Array[ThrusterCommand] = []
var _latest_stabilization := StabilizationOutput.new()
var _latest_input := PilotInputState.new()
var _latest_controlled_input := PilotInputState.new()
var _stabilizer_enabled: bool = true
var _hover_enabled: bool = false
var _hover_target_altitude: float = 0.0
var _hover_auto_throttle: float = 0.0
var _stabilizer_toggle_requested: bool = false
var _hover_toggle_requested: bool = false
var _reset_requested: bool = false
var _spawn_transform: Transform3D
var _debug_snapshot: Dictionary = {}
var _space_world: SpaceWorld
var _gravity_context: Dictionary = {}

@onready var _computer: ShipComputerLogic = $Components/ShipComputer
@onready var _pilot_seat: PilotSeatLogic = $Components/PilotSeat
@onready var _engine: EngineLogic = $Components/MainEngine
@onready var _power_source: PowerSourceLogic = $Components/SolarBattery


func _ready() -> void:
    PilotInput.ensure_actions()
    can_sleep = false
    contact_monitor = true
    max_contacts_reported = 8
    _spawn_transform = global_transform
    _collect_thrusters()
    _computer.configure(_pilot_seat, _engine, _power_source, _thruster_nodes)
    if not _computer.mode_command_dispatched.is_connected(_on_mode_command):
        _computer.mode_command_dispatched.connect(_on_mode_command)
    print("[VEHICLE] component architecture online")
    reset_physics_interpolation()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    _apply_pending_reset(state)
    _update_gravity_context(state.transform.origin)
    _apply_mode_requests(state)

    _computer.tick_power_system(state.step)
    _latest_input = _computer.sample_pilot_from(_pilot_seat)
    _latest_stabilization = calculate_stabilization(state)
    _latest_controlled_input = calculate_requested_motion(
        state,
        _latest_input,
        _latest_stabilization
    )
    _latest_commands = distribute_power_to_thrusters(
        _latest_controlled_input,
        _latest_stabilization
    )

    var total_available := ThrusterLibrary.total_available_thrust(_max_thrusts)
    var requested_thrust := ThrusterLibrary.total_requested_thrust(_latest_commands)
    var requested_engine_ratio := requested_thrust / maxf(total_available, 0.001)
    _computer.request_engine_power(requested_engine_ratio, state.step)
    var supply_fraction := _computer.get_engine_supply_fraction(requested_engine_ratio)
    ThrusterLibrary.apply_power_fraction(_latest_commands, supply_fraction)

    for command: ThrusterCommand in _latest_commands:
        _computer.route_thruster_command(command)

    apply_thruster_forces(state, _latest_commands)
    update_debug_metrics(state)


func calculate_stabilization(state: PhysicsDirectBodyState3D) -> StabilizationOutput:
    var target_up := state.transform.basis.orthonormalized().y.normalized()
    if _has_local_gravity(state):
        target_up = -state.total_gravity.normalized()

    return StabilizerLibrary.calculate(
        state.transform.basis,
        state.angular_velocity,
        _latest_input.yaw,
        _stabilizer_enabled,
        target_up,
        stabilization_kp,
        stabilization_kd,
        yaw_damping,
        max_yaw_correction,
        soft_tilt_limit_degrees,
        hard_tilt_limit_degrees,
        anti_flip_gain
    )


func calculate_requested_motion(
        state: PhysicsDirectBodyState3D,
        pilot: PilotInputState,
        stabilization: StabilizationOutput
) -> PilotInputState:
    var controlled := PilotInputState.new()

    var move_authority := 1.0
    var yaw_authority := 1.0
    if stabilization.enabled:
        move_authority = stabilization.pilot_move_authority
        yaw_authority = stabilization.pilot_yaw_authority

    controlled.move = pilot.move * move_authority
    controlled.yaw = pilot.yaw * yaw_authority
    controlled.lift = calculate_requested_lift(state, pilot.lift, controlled.move)

    for index: int in range(controlled.manual_thruster_boosts.size()):
        controlled.manual_thruster_boosts[index] = pilot.manual_thruster_boosts[index]

    return controlled


func calculate_requested_lift(
        state: PhysicsDirectBodyState3D,
        manual_lift: float,
        controlled_move: Vector2
) -> float:
    if not _hover_enabled:
        _hover_auto_throttle = manual_lift
        return manual_lift

    if not _has_local_gravity(state) or not bool(_gravity_context.get("active", false)):
        _hover_enabled = false
        _hover_auto_throttle = manual_lift
        return manual_lift

    var local_up := -state.total_gravity.normalized()
    var total_available := ThrusterLibrary.total_available_thrust(_max_thrusts)
    var gravity_force := mass * state.total_gravity.length()
    var body_up := state.transform.basis.orthonormalized().y.normalized()
    var upright_component := maxf(body_up.dot(local_up), 0.40)
    var gimbal_component := cos(
        deg_to_rad(_average_max_gimbal()) * clampf(controlled_move.length(), 0.0, 1.0)
    )
    var vertical_authority := maxf(upright_component * gimbal_component, 0.35)
    var neutral_hover := gravity_force / maxf(total_available * vertical_authority, 0.001)

    var current_altitude := float(_gravity_context.get("surface_altitude", 0.0))
    var vertical_velocity := state.linear_velocity.dot(local_up)
    var altitude_error := _hover_target_altitude - current_altitude
    var altitude_correction := clampf(
        altitude_error * hover_kp - vertical_velocity * hover_kd,
        -hover_max_correction,
        hover_max_correction
    )

    _hover_auto_throttle = clampf(neutral_hover + altitude_correction, 0.0, 1.0)
    return _hover_auto_throttle


func distribute_power_to_thrusters(
        pilot: PilotInputState,
        stabilization: StabilizationOutput
) -> Array[ThrusterCommand]:
    return ThrusterLibrary.build_commands(
        _mount_ids,
        _mount_positions,
        _max_thrusts,
        _max_gimbals,
        pilot,
        stabilization,
        stabilization_mix,
        max_stabilization_throttle
    )


func apply_thruster_forces(
        state: PhysicsDirectBodyState3D,
        commands: Array[ThrusterCommand]
) -> void:
    var body_basis := state.transform.basis.orthonormalized()

    for command: ThrusterCommand in commands:
        var world_force := body_basis * (command.local_direction * command.effective_thrust)
        var world_offset := body_basis * command.local_position
        state.apply_force(world_force, world_offset)


func update_debug_metrics(state: PhysicsDirectBodyState3D) -> void:
    var power_snapshot := _power_source.get_snapshot()
    var engine_snapshot := _engine.get_snapshot()
    _debug_snapshot = {
        "stabilizer_enabled": _stabilizer_enabled,
        "hover_enabled": _hover_enabled,
        "hover_target_altitude": _hover_target_altitude,
        "altitude": float(_gravity_context.get("surface_altitude", INF)),
        "gravity_active": _has_local_gravity(state),
        "gravity_strength": state.total_gravity.length(),
        "battery_ratio": float(power_snapshot.get("battery_ratio", 0.0)),
        "engine_output_ratio": float(engine_snapshot.get("actual_output_ratio", 0.0)),
    }


func get_debug_snapshot() -> Dictionary:
    return _debug_snapshot.duplicate(true)


func get_engine_component() -> EngineLogic:
    return _engine


func get_power_source_component() -> PowerSourceLogic:
    return _power_source


func get_ship_computer() -> ShipComputerLogic:
    return _computer


func configure_space_world(space_world: SpaceWorld) -> void:
    _space_world = space_world
    print("[VEHICLE] local asteroid gravity context connected")


func configure_spawn_transform(spawn_transform: Transform3D) -> void:
    global_transform = spawn_transform
    _spawn_transform = spawn_transform
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    reset_physics_interpolation()
    print("[VEHICLE] spawn configured at world y=%.2f" % _spawn_transform.origin.y)


func _collect_thrusters() -> void:
    _thruster_nodes.clear()
    _mount_ids.clear()
    _mount_positions.clear()
    _max_thrusts.clear()
    _max_gimbals.clear()

    for child: Node in $Thrusters.get_children():
        if child is ThrusterLogic:
            var thruster := child as ThrusterLogic
            _thruster_nodes.append(thruster)
            _mount_ids.append(thruster.mount_id)
            _mount_positions.append(thruster.position)
            _max_thrusts.append(thruster.max_thrust)
            _max_gimbals.append(thruster.max_gimbal_degrees)

    if _thruster_nodes.size() != 4:
        push_warning("Prototype expects exactly four thruster components; found %d." % _thruster_nodes.size())


func _average_max_gimbal() -> float:
    if _max_gimbals.is_empty():
        return 18.0
    var total := 0.0
    for value: float in _max_gimbals:
        total += value
    return total / float(_max_gimbals.size())


func _update_gravity_context(world_position: Vector3) -> void:
    if _space_world == null:
        _gravity_context = {}
        return
    _gravity_context = _space_world.get_gravity_context(world_position)


func _has_local_gravity(state: PhysicsDirectBodyState3D) -> bool:
    var threshold := 0.15
    if _space_world != null and _space_world.settings != null:
        threshold = _space_world.settings.zero_gravity_threshold
    return state.total_gravity.length() > threshold


func _on_mode_command(command: StringName) -> void:
    print("[VEHICLE] LISTENER mode_command %s" % String(command))
    match command:
        &"stabilizer_toggle":
            _stabilizer_toggle_requested = true
        &"hover_toggle":
            _hover_toggle_requested = true
        &"reset":
            _reset_requested = true


func _apply_mode_requests(state: PhysicsDirectBodyState3D) -> void:
    if _stabilizer_toggle_requested:
        _stabilizer_enabled = not _stabilizer_enabled
        if not _stabilizer_enabled:
            _hover_enabled = false
        _stabilizer_toggle_requested = false

    if _hover_toggle_requested:
        if _hover_enabled:
            _hover_enabled = false
        elif _has_local_gravity(state) and bool(_gravity_context.get("active", false)):
            _hover_enabled = true
            _stabilizer_enabled = true
            _hover_target_altitude = float(_gravity_context.get("surface_altitude", 0.0))
        _hover_toggle_requested = false


func _apply_pending_reset(state: PhysicsDirectBodyState3D) -> void:
    if not _reset_requested:
        return

    state.transform = _spawn_transform
    state.linear_velocity = Vector3.ZERO
    state.angular_velocity = Vector3.ZERO
    _hover_enabled = false
    _hover_auto_throttle = 0.0
    _reset_requested = false
    reset_physics_interpolation()
