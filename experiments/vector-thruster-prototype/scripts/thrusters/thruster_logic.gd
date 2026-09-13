class_name ThrusterLogic
extends Node3D

signal status_changed(mount_id: StringName, throttle: float, thrust: float, gimbal_degrees: float)

@export var mount_id: StringName = &"thruster"
@export var max_thrust: float = 520.0
@export_range(1.0, 35.0, 0.5) var max_gimbal_degrees: float = 18.0
@export var debug_events: bool = true

var _latest_command := ThrusterCommand.new()
var _visual: ThrusterVisual
var _last_log_ms: int = 0
var _last_logged_throttle: float = -1.0
var _last_logged_gimbal: float = -1.0


func _ready() -> void:
    _visual = ThrusterVisual.new()
    _visual.name = "Visual"
    add_child(_visual)
    _latest_command.mount_id = mount_id
    _latest_command.max_thrust = max_thrust
    _trace("READY nozzle max %.0f N gimbal %.1f deg" % [max_thrust, max_gimbal_degrees])


func listen_thruster_command(command: ThrusterCommand) -> void:
    if command.mount_id != mount_id:
        return
    _trace_rate_limited(command)
    _latest_command = command
    set_throttle(command.effective_throttle, command.power_fraction)
    set_vector_direction(command.local_direction)
    if _visual != null:
        _visual.set_output(_latest_command.local_direction, _latest_command.effective_throttle)
    status_changed.emit(
        mount_id,
        _latest_command.effective_throttle,
        _latest_command.effective_thrust,
        _latest_command.gimbal_degrees
    )


func set_throttle(throttle: float, power_fraction: float = 1.0) -> void:
    _latest_command.effective_throttle = clampf(throttle, 0.0, 1.0)
    _latest_command.power_fraction = clampf(power_fraction, 0.0, 1.0)


func set_vector_direction(local_direction: Vector3) -> void:
    var direction := local_direction.normalized()
    if direction.length_squared() < 0.0001:
        direction = Vector3.UP
    _latest_command.local_direction = direction


func get_snapshot() -> Dictionary:
    return {
        "id": mount_id,
        "throttle": _latest_command.effective_throttle,
        "requested_throttle": _latest_command.requested_throttle,
        "power_fraction": _latest_command.power_fraction,
        "thrust": _latest_command.effective_thrust,
        "max_thrust": max_thrust,
        "gimbal_degrees": _latest_command.gimbal_degrees,
    }


func _trace(message: String) -> void:
    if debug_events:
        print("[THRUSTER:%s] %s" % [String(mount_id), message])


func _trace_rate_limited(command: ThrusterCommand) -> void:
    if not debug_events:
        return
    var now := Time.get_ticks_msec()
    if (
        now - _last_log_ms < 650
        and absf(command.effective_throttle - _last_logged_throttle) < 0.14
        and absf(command.gimbal_degrees - _last_logged_gimbal) < 5.0
    ):
        return
    _last_log_ms = now
    _last_logged_throttle = command.effective_throttle
    _last_logged_gimbal = command.gimbal_degrees
    _trace(
        "LISTENER control -> set_throttle %.0f%% set_vector %.1f deg (power %.0f%%)" % [
            command.effective_throttle * 100.0,
            command.gimbal_degrees,
            command.power_fraction * 100.0,
        ]
    )
