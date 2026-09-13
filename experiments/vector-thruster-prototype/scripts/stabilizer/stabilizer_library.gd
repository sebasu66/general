class_name StabilizerLibrary
extends RefCounted


static func calculate(
        body_basis: Basis,
        angular_velocity_world: Vector3,
        user_yaw: float,
        enabled: bool,
        proportional_gain: float,
        derivative_gain: float,
        yaw_damping: float,
        max_yaw_correction: float,
        soft_tilt_degrees: float,
        hard_tilt_degrees: float,
        anti_flip_gain: float
) -> StabilizationOutput:
    var output := StabilizationOutput.new()
    output.enabled = enabled

    var stable_basis := body_basis.orthonormalized()
    var world_to_local := stable_basis.transposed()
    var body_up_world := stable_basis.y.normalized()
    var up_alignment := clampf(body_up_world.dot(Vector3.UP), -1.0, 1.0)

    output.level_error_local = world_to_local * body_up_world.cross(Vector3.UP)
    output.angular_velocity_local = world_to_local * angular_velocity_world
    output.tilt_degrees = rad_to_deg(acos(up_alignment))

    if not enabled:
        return output

    output.tilt_guard = smoothstep(
        soft_tilt_degrees,
        maxf(hard_tilt_degrees, soft_tilt_degrees + 0.1),
        output.tilt_degrees
    )
    output.pilot_move_authority = 1.0 - output.tilt_guard
    output.pilot_yaw_authority = 1.0 - output.tilt_guard * 0.75

    var proportional_scale := lerpf(1.0, anti_flip_gain, output.tilt_guard)
    var derivative_scale := lerpf(1.0, 1.65, output.tilt_guard)

    var pitch_command := (
        proportional_gain * proportional_scale * output.level_error_local.x
        - derivative_gain * derivative_scale * output.angular_velocity_local.x
    )
    var roll_command := (
        proportional_gain * proportional_scale * output.level_error_local.z
        - derivative_gain * derivative_scale * output.angular_velocity_local.z
    )

    output.level_command = Vector2(
        clampf(pitch_command, -1.0, 1.0),
        clampf(roll_command, -1.0, 1.0)
    )

    var user_yaw_authority := (
        1.0 - clampf(absf(user_yaw), 0.0, 1.0)
    ) * output.pilot_yaw_authority
    output.yaw_correction = clampf(
        -output.angular_velocity_local.y * yaw_damping,
        -max_yaw_correction,
        max_yaw_correction
    ) * user_yaw_authority

    output.correction_strength = clampf(
        maxf(output.level_command.length(), output.tilt_guard),
        0.0,
        1.0
    )
    return output
