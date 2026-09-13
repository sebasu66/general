class_name ThrusterCommand
extends RefCounted

var mount_id: StringName = &""
var local_position: Vector3 = Vector3.ZERO
var local_direction: Vector3 = Vector3.UP
var base_throttle: float = 0.0
var stabilization_correction: float = 0.0
var manual_boost: float = 0.0
var requested_throttle: float = 0.0
var effective_throttle: float = 0.0
var effective_thrust: float = 0.0
var max_thrust: float = 0.0
var power_fraction: float = 1.0
var gimbal_degrees: float = 0.0
