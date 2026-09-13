class_name PilotInputState
extends RefCounted

var lift: float = 0.0
var move: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var manual_thruster_boosts: Array[float] = []


func _init() -> void:
    manual_thruster_boosts = [0.0, 0.0, 0.0, 0.0]
