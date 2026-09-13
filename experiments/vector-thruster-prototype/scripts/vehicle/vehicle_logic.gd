class_name VehicleLogic
extends RigidBody3D

@export_group("Thrusters")
@export var max_thrust_per_thruster: float = 520.0
@export_range(1.0, 35.0, 0.5) var max_gimbal_degrees: float = 18.0

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

var _thruster_nodes: Array[ThrusterVisual] = []
var _mount_ids: Array[StringName] = []
var _mount_positions: Array[Vector3] = []
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

@onready var _engine_audio: ThrusterAudio = $EngineAudio


func _ready() -> void:
    PilotInput.ensure_actions()
    can_sleep = false
    contact_monitor = true
    max_contacts_reported = 8
    _spawn_transform = global_transform
    _collect_thrusters()
    reset_physics_interpolation()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return

    if event.is_action_pressed(PilotInput.STABILIZER_TOGGLE):
        _stabilizer_toggle_requested = true
        get_viewport().set_input_as_handled()

    if event.is_action_pressed(PilotInput.HOVER_TOGGLE):
        _hover_toggle_requested = true
        get_viewport().set_input_as_handled()

    if event.is_action_pressed(PilotInput.RESET):
        _reset_requested = true
        get_viewport().set_input_as_handled()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    _apply_pending_reset(state)
    _apply_mode_requests(state)

    _latest_input = PilotInput.read_continuous()
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
    apply_thruster_forces(state, _latest_commands)
    update_debug_metrics(state, _latest_commands)


func _physics_process(_delta: float) -> void:
    update_thruster_visuals(_latest_commands)
    update_engine_audio(_latest_commands)


func calculate_stabilization(state: PhysicsDirectBodyState3D) -> StabilizationOutput:
    return StabilizerLibrary.calculate(
        state.transform.basis,
        state.angular_velocity,
        _latest_input.yaw,
        _stabilizer_enabled,
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

    var thruster_count := maxi(_thruster_nodes.size(), 1)
    var total_available := max_thrust_per_thruster * float(thruster_count)
    var gravity_force := mass * state.total_gravity.length()
    var body_up := state.transform.basis.orthonormalized().y.normalized()
    var upright_component := maxf(body_up.dot(Vector3.UP), 0.40)
    var gimbal_component := cos(
        deg_to_rad(max_gimbal_degrees) * clampf(controlled_move.length(), 0.0, 1.0)
    )
    var vertical_authority := maxf(upright_component * gimbal_component, 0.35)
    var neutral_hover := gravity_force / maxf(total_available * vertical_authority, 0.001)

    var altitude_error := _hover_target_altitude - state.transform.origin.y
    var altitude_correction := clampf(
        altitude_error * hover_kp - state.linear_velocity.y * hover_kd,
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
        pilot,
        stabilization,
        max_thrust_per_thruster,
        max_gimbal_degrees,
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


func update_thruster_visuals(commands: Array[ThrusterCommand]) -> void:
    var count := mini(commands.size(), _thruster_nodes.size())
    for index: int in range(count):
        var ratio := commands[index].effective_thrust / maxf(max_thrust_per_thruster, 0.001)
        _thruster_nodes[index].set_output(commands[index].local_direction, ratio)


func update_engine_audio(commands: Array[ThrusterCommand]) -> void:
    if _engine_audio == null:
        return
    var total_available := max_thrust_per_thruster * float(maxi(_thruster_nodes.size(), 1))
    var ratio := ThrusterLibrary.total_thrust(commands) / maxf(total_available, 0.001)
    _engine_audio.set_intensity(ratio)


func update_debug_metrics(
        state: PhysicsDirectBodyState3D,
        commands: Array[ThrusterCommand]
) -> void:
    var orientation_radians := state.transform.basis.orthonormalized().get_euler()
    var orientation_degrees := Vector3(
        rad_to_deg(orientation_radians.x),
        rad_to_deg(orientation_radians.y),
        rad_to_deg(orientation_radians.z)
    )

    var thruster_metrics: Array[Dictionary] = []
    for command: ThrusterCommand in commands:
        thruster_metrics.append({
            "id": command.mount_id,
            "base_throttle": command.base_throttle,
            "stabilization": command.stabilization_correction,
            "manual_boost": command.manual_boost,
            "effective_throttle": command.effective_throttle,
            "thrust": command.effective_thrust,
            "max_thrust": max_thrust_per_thruster,
            "gimbal_degrees": command.gimbal_degrees,
            "direction": command.local_direction,
        })

    _debug_snapshot = {
        "mass": mass,
        "gravity_acceleration": state.total_gravity.length(),
        "gravity_force": mass * state.total_gravity.length(),
        "hover_throttle_estimate": (mass * state.total_gravity.length()) / maxf(max_thrust_per_thruster * float(_thruster_nodes.size()), 0.001),
        "lift_input": _latest_input.lift,
        "controlled_lift": _latest_controlled_input.lift,
        "move_input": _latest_input.move,
        "controlled_move": _latest_controlled_input.move,
        "yaw_input": _latest_input.yaw,
        "linear_velocity": state.linear_velocity,
        "speed": state.linear_velocity.length(),
        "vertical_speed": state.linear_velocity.y,
        "altitude": state.transform.origin.y,
        "angular_velocity": state.angular_velocity,
        "orientation_degrees": orientation_degrees,
        "total_available_thrust": max_thrust_per_thruster * float(_thruster_nodes.size()),
        "total_actual_thrust": ThrusterLibrary.total_thrust(commands),
        "stabilizer_enabled": _stabilizer_enabled,
        "stabilizer_level_error": _latest_stabilization.level_error_local,
        "stabilizer_command": _latest_stabilization.level_command,
        "stabilizer_strength": _latest_stabilization.correction_strength,
        "tilt_degrees": _latest_stabilization.tilt_degrees,
        "tilt_guard": _latest_stabilization.tilt_guard,
        "pilot_move_authority": _latest_stabilization.pilot_move_authority,
        "hover_enabled": _hover_enabled,
        "hover_target_altitude": _hover_target_altitude,
        "hover_auto_throttle": _hover_auto_throttle,
        "thrusters": thruster_metrics,
    }


func get_debug_snapshot() -> Dictionary:
    return _debug_snapshot.duplicate(true)


func _collect_thrusters() -> void:
    _thruster_nodes.clear()
    _mount_ids.clear()
    _mount_positions.clear()

    for child: Node in $Thrusters.get_children():
        if child is ThrusterVisual:
            var thruster := child as ThrusterVisual
            _thruster_nodes.append(thruster)
            _mount_ids.append(thruster.mount_id)
            _mount_positions.append(thruster.position)

    if _thruster_nodes.size() != 4:
        push_warning("Prototype expects exactly four thrusters; found %d." % _thruster_nodes.size())


func _apply_mode_requests(state: PhysicsDirectBodyState3D) -> void:
    if _stabilizer_toggle_requested:
        _stabilizer_enabled = not _stabilizer_enabled
        if not _stabilizer_enabled:
            _hover_enabled = false
        _stabilizer_toggle_requested = false

    if _hover_toggle_requested:
        _hover_enabled = not _hover_enabled
        if _hover_enabled:
            _stabilizer_enabled = true
            _hover_target_altitude = state.transform.origin.y
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
