class_name PrototypeFollowCamera
extends Camera3D

@export var follow_offset: Vector3 = Vector3(10.5, 8.5, 12.5)
@export var look_height: float = 0.45
@export var follow_speed: float = 7.0

var target: Node3D


func _process(delta: float) -> void:
    if target == null:
        return

    var target_transform := target.get_global_transform_interpolated()
    var look_target := target_transform.origin + Vector3.UP * look_height
    var desired_position := target_transform.origin + follow_offset
    var blend := 1.0 - exp(-follow_speed * delta)

    global_position = global_position.lerp(desired_position, blend)
    look_at(look_target, Vector3.UP)


func snap_to_target() -> void:
    if target == null:
        return

    var target_position := target.global_position
    global_position = target_position + follow_offset
    look_at(target_position + Vector3.UP * look_height, Vector3.UP)
