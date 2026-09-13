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
        max_yaw_correction: float
) -> StabilizationOutput:
    var output := StabilizationOutput.new()
    output.enabled = enabled

    var stable_basis := body_basis.orthonormalized()
    var world_to_local := stable_basis.transposed()
    var body_up_world := stable_basis.y.normalized()

    output.level_error_local = world_to_local * body_up_world.cross(Vector3.UP)
    output.angular_velocity_local = world_to_local * angular_velocity_world

    if not enabled:
        return output

    var pitch_command := proportional_gain * output.level_error_local.x - derivative_gain * output.angular_velocity_local.x
    var roll_command := proportional_gain * output.level_error_local.z - derivative_gain * output.angular_velocity_local.z

    output.level_command = Vector2(
        clampf(pitch_command, -1.0, 1.0),
        clampf(roll_command, -1.0, 1.0)
    )

    var user_yaw_authority := 1.0 - clampf(absf(user_yaw), 0.0, 1.0)
    output.yaw_correction = clampf(
        -output.angular_velocity_local.y * yaw_damping,
        -max_yaw_correction,
        max_yaw_correction
    ) * user_yaw_authority

    output.correction_strength = clampf(output.level_command.length(), 0.0, 1.0)
    return output
