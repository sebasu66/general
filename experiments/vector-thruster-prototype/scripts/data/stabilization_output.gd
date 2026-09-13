class_name StabilizationOutput
extends RefCounted

var enabled: bool = true
var level_error_local: Vector3 = Vector3.ZERO
var angular_velocity_local: Vector3 = Vector3.ZERO
var level_command: Vector2 = Vector2.ZERO
var yaw_correction: float = 0.0
var correction_strength: float = 0.0
var tilt_degrees: float = 0.0
var tilt_guard: float = 0.0
var pilot_move_authority: float = 1.0
var pilot_yaw_authority: float = 1.0
