class_name ThrusterLibrary
extends RefCounted

const MANUAL_DIAGNOSTIC_BOOST: float = 0.28
const YAW_VECTOR_WEIGHT: float = 0.62
const SPACE_STEER_VECTOR_WEIGHT: float = 0.72
const SPACE_STEERING_THROTTLE: float = 0.68
const SPACE_FRONT_CRUISE_MIX: float = 0.12
const SPACE_STABILIZER_STEER_MIX: float = 1.0
const SPACE_YAW_DAMPING_GAIN: float = 1.65


static func build_commands(
        mount_ids: Array[StringName],
        mount_positions: Array[Vector3],
        max_thrusts: Array[float],
        max_gimbal_degrees: Array[float],
        pilot: PilotInputState,
        stabilization: StabilizationOutput,
        stabilization_mix: float,
        max_stabilization_throttle: float
) -> Array[ThrusterCommand]:
    var commands: Array[ThrusterCommand] = []
    var max_x := _max_mount_extent(mount_positions, true)
    var max_z := _max_mount_extent(mount_positions, false)
    var effective_yaw := clampf(-pilot.yaw + stabilization.yaw_correction, -1.0, 1.0)

    for index: int in range(mount_positions.size()):
        var mount := mount_positions[index]
        var max_thrust := _float_at(max_thrusts, index, 520.0)
        var max_gimbal := _float_at(max_gimbal_degrees, index, 18.0)
        var command := ThrusterCommand.new()
        command.mount_id = mount_ids[index]
        command.local_position = mount
        command.max_thrust = max_thrust
        command.base_throttle = pilot.lift
        command.stabilization_correction = _calculate_level_throttle_correction(
            mount,
            max_x,
            max_z,
            stabilization,
            max_stabilization_throttle
        ) * stabilization_mix
        command.manual_boost = _manual_boost_at(pilot, index) * MANUAL_DIAGNOSTIC_BOOST
        command.requested_throttle = clampf(
            command.base_throttle + command.stabilization_correction + command.manual_boost,
            0.0,
            1.0
        )
        command.effective_throttle = command.requested_throttle
        command.local_direction = calculate_thrust_direction(
            pilot.move,
            effective_yaw,
            mount,
            max_gimbal
        )
        command.effective_thrust = command.effective_throttle * command.max_thrust
        command.gimbal_degrees = rad_to_deg(acos(clampf(command.local_direction.dot(Vector3.UP), -1.0, 1.0)))
        commands.append(command)

    return commands


static func build_space_commands(
        mount_ids: Array[StringName],
        mount_positions: Array[Vector3],
        max_thrusts: Array[float],
        pilot: PilotInputState,
        stabilization: StabilizationOutput
) -> Array[ThrusterCommand]:
    var commands: Array[ThrusterCommand] = []

    # In zero-G the stabilizer is an angular-rate damper, not a horizon keeper.
    # Pilot input wins while the stick is held; once released, the same front
    # vector thrusters actively oppose pitch/roll/yaw angular velocity.
    var pitch_request := clampf(
        pilot.move.y + stabilization.level_command.x * SPACE_STABILIZER_STEER_MIX,
        -1.0,
        1.0
    )
    var roll_request := clampf(
        pilot.move.x + stabilization.level_command.y * SPACE_STABILIZER_STEER_MIX,
        -1.0,
        1.0
    )
    var yaw_request := clampf(
        pilot.yaw + stabilization.yaw_correction * SPACE_YAW_DAMPING_GAIN,
        -1.0,
        1.0
    )
    var steering_strength := clampf(
        maxf(absf(pitch_request), maxf(absf(roll_request), absf(yaw_request))),
        0.0,
        1.0
    )

    for index: int in range(mount_positions.size()):
        var mount := mount_positions[index]
        var command := ThrusterCommand.new()
        command.mount_id = mount_ids[index]
        command.local_position = mount
        command.max_thrust = _float_at(max_thrusts, index, 520.0)
        command.manual_boost = _manual_boost_at(pilot, index) * MANUAL_DIAGNOSTIC_BOOST

        var is_front := mount.z < 0.0
        if is_front:
            var side_sign := 1.0 if mount.x >= 0.0 else -1.0
            var vertical_steer := clampf(
                pitch_request - roll_request * side_sign,
                -1.0,
                1.0
            )
            var lateral_steer := yaw_request
            command.base_throttle = pilot.lift * SPACE_FRONT_CRUISE_MIX
            command.requested_throttle = clampf(
                maxf(command.base_throttle, steering_strength * SPACE_STEERING_THROTTLE)
                + command.manual_boost,
                0.0,
                1.0
            )
            command.local_direction = Vector3(
                lateral_steer * SPACE_STEER_VECTOR_WEIGHT,
                vertical_steer * SPACE_STEER_VECTOR_WEIGHT,
                -1.0
            ).normalized()
        else:
            command.base_throttle = pilot.lift
            command.requested_throttle = clampf(
                command.base_throttle + command.manual_boost,
                0.0,
                1.0
            )
            command.local_direction = Vector3.FORWARD

        command.effective_throttle = command.requested_throttle
        command.effective_thrust = command.effective_throttle * command.max_thrust
        command.gimbal_degrees = rad_to_deg(acos(clampf(command.local_direction.dot(Vector3.UP), -1.0, 1.0)))
        commands.append(command)

    return commands


static func apply_power_fraction(
        commands: Array[ThrusterCommand],
        supply_fraction: float
) -> void:
    var fraction := clampf(supply_fraction, 0.0, 1.0)
    for command: ThrusterCommand in commands:
        command.power_fraction = fraction
        command.effective_throttle = command.requested_throttle * fraction
        command.effective_thrust = command.effective_throttle * command.max_thrust


static func calculate_thrust_direction(
        move_input: Vector2,
        yaw_input: float,
        mount_position: Vector3,
        max_gimbal_degrees: float
) -> Vector3:
    var horizontal_request := Vector3(move_input.x, 0.0, move_input.y)
    if horizontal_request.length_squared() > 1.0:
        horizontal_request = horizontal_request.normalized()

    var yaw_tangent := Vector3(mount_position.z, 0.0, -mount_position.x)
    if yaw_tangent.length_squared() > 0.0001:
        yaw_tangent = yaw_tangent.normalized() * yaw_input * YAW_VECTOR_WEIGHT

    horizontal_request += yaw_tangent
    var request_magnitude := clampf(horizontal_request.length(), 0.0, 1.0)
    if request_magnitude < 0.0001:
        return Vector3.UP

    horizontal_request = horizontal_request.normalized()
    var tilt := deg_to_rad(max_gimbal_degrees) * request_magnitude
    return Vector3(
        horizontal_request.x * sin(tilt),
        cos(tilt),
        horizontal_request.z * sin(tilt)
    ).normalized()


static func total_thrust(commands: Array[ThrusterCommand]) -> float:
    var total := 0.0
    for command: ThrusterCommand in commands:
        total += command.effective_thrust
    return total


static func total_requested_thrust(commands: Array[ThrusterCommand]) -> float:
    var total := 0.0
    for command: ThrusterCommand in commands:
        total += command.requested_throttle * command.max_thrust
    return total


static func total_available_thrust(max_thrusts: Array[float]) -> float:
    var total := 0.0
    for value: float in max_thrusts:
        total += maxf(value, 0.0)
    return total


static func _calculate_level_throttle_correction(
        mount: Vector3,
        max_x: float,
        max_z: float,
        stabilization: StabilizationOutput,
        max_correction: float
) -> float:
    if not stabilization.enabled:
        return 0.0

    var pitch_arm := -mount.z / maxf(max_z, 0.001)
    var roll_arm := mount.x / maxf(max_x, 0.001)
    var correction := (
        pitch_arm * stabilization.level_command.x
        + roll_arm * stabilization.level_command.y
    ) * 0.5 * max_correction
    return clampf(correction, -max_correction, max_correction)


static func _max_mount_extent(mount_positions: Array[Vector3], use_x: bool) -> float:
    var extent := 0.0
    for mount: Vector3 in mount_positions:
        extent = maxf(extent, absf(mount.x if use_x else mount.z))
    return maxf(extent, 0.001)


static func _manual_boost_at(pilot: PilotInputState, index: int) -> float:
    if index < 0 or index >= pilot.manual_thruster_boosts.size():
        return 0.0
    return pilot.manual_thruster_boosts[index]


static func _float_at(values: Array[float], index: int, fallback: float) -> float:
    if index < 0 or index >= values.size():
        return fallback
    return values[index]
