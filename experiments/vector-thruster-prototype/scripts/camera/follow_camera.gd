class_name PrototypeFollowCamera
extends Camera3D

@export var follow_offset: Vector3 = Vector3(0.0, 4.8, 11.5)
@export var look_height: float = 0.55
@export var look_ahead: float = 3.0
@export var follow_speed: float = 8.0

var target: Node3D


func _process(delta: float) -> void:
    if target == null:
        return

    var target_transform := target.get_global_transform_interpolated()
    var target_basis := target_transform.basis.orthonormalized()
    var target_up := target_basis.y.normalized()
    var target_forward := -target_basis.z.normalized()
    var desired_position := target_transform.origin + target_basis * follow_offset
    var look_target := (
        target_transform.origin
        + target_up * look_height
        + target_forward * look_ahead
    )
    var blend := 1.0 - exp(-follow_speed * delta)

    global_position = global_position.lerp(desired_position, blend)
    look_at(look_target, target_up)


func snap_to_target() -> void:
    if target == null:
        return

    var target_transform := target.global_transform
    var target_basis := target_transform.basis.orthonormalized()
    var target_up := target_basis.y.normalized()
    var target_forward := -target_basis.z.normalized()
    global_position = target_transform.origin + target_basis * follow_offset
    look_at(
        target_transform.origin + target_up * look_height + target_forward * look_ahead,
        target_up
    )
