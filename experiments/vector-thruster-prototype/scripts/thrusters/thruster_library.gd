class_name ThrusterLibrary
extends RefCounted

const MANUAL_DIAGNOSTIC_BOOST: float = 0.28
const YAW_VECTOR_WEIGHT: float = 0.62


static func build_commands(
        mount_ids: Array[StringName],
        mount_positions: Array[Vector3],
        pilot: PilotInputState,
        stabilization: StabilizationOutput,
        max_thrust_per_thruster: float,
        max_gimbal_degrees: float,
        stabilization_mix: float,
        max_stabilization_throttle: float
) -> Array[ThrusterCommand]:
    var commands: Array[ThrusterCommand] = []
    var max_x := _max_mount_extent(mount_positions, true)
    var max_z := _max_mount_extent(mount_positions, false)
    var effective_yaw := clampf(-pilot.yaw + stabilization.yaw_correction, -1.0, 1.0)

    for index: int in range(mount_positions.size()):
        var mount := mount_positions[index]
        var command := ThrusterCommand.new()
        command.mount_id = mount_ids[index]
        command.local_position = mount
        command.base_throttle = pilot.lift
        command.stabilization_correction = _calculate_level_throttle_correction(
            mount,
            max_x,
            max_z,
            stabilization,
            max_stabilization_throttle
        ) * stabilization_mix
        command.manual_boost = _manual_boost_at(pilot, index) * MANUAL_DIAGNOSTIC_BOOST
        command.effective_throttle = clampf(
            command.base_throttle + command.stabilization_correction + command.manual_boost,
            0.0,
            1.0
        )
        command.local_direction = calculate_thrust_direction(
            pilot.move,
            effective_yaw,
            mount,
            max_gimbal_degrees
        )
        command.effective_thrust = command.effective_throttle * max_thrust_per_thruster
        command.gimbal_degrees = rad_to_deg(acos(clampf(command.local_direction.dot(Vector3.UP), -1.0, 1.0)))
        commands.append(command)

    return commands


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
