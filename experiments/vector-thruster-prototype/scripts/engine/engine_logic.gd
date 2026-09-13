class_name EngineLogic
extends Node3D

signal energy_requested(consumer_id: StringName, amount: float)
signal output_changed(requested_ratio: float, actual_ratio: float, consumption_per_second: float)
signal status_changed(snapshot: Dictionary)

@export var component_id: StringName = &"main_engine"
@export var required_power_type: StringName = &"electric"
@export var max_consumption_per_second: float = 100.0
@export var debug_events: bool = true

var _requested_output_ratio: float = 0.0
var _actual_output_ratio: float = 0.0
var _consumption_per_second: float = 0.0
var _pending_energy_request: float = 0.0
var _pending_delta: float = 0.0
var _last_log_ms: int = 0
var _last_logged_output: float = -1.0
var _audio: ThrusterAudio


func _ready() -> void:
    _build_visual()
    _audio = ThrusterAudio.new()
    _audio.name = "EngineSound"
    add_child(_audio)
    _trace("READY motor online; fuel interface=%s" % String(required_power_type))


func listen_engine_power_request(requested_ratio: float, delta: float) -> void:
    _requested_output_ratio = clampf(requested_ratio, 0.0, 1.0)
    _pending_delta = maxf(delta, 0.000001)
    _pending_energy_request = EngineLibrary.energy_required(
        _requested_output_ratio,
        max_consumption_per_second,
        _pending_delta
    )

    if _pending_energy_request <= 0.000001:
        _actual_output_ratio = 0.0
        _consumption_per_second = 0.0
        _publish_output()
        return

    _trace_rate_limited(
        "LISTENER engine_power_request %.1f%% -> TRIGGER energy_requested %.3f u" % [
            _requested_output_ratio * 100.0,
            _pending_energy_request,
        ],
        _requested_output_ratio
    )
    energy_requested.emit(component_id, _pending_energy_request)


func listen_energy_grant(consumer_id: StringName, requested: float, granted: float) -> void:
    if consumer_id != component_id:
        return

    _actual_output_ratio = EngineLibrary.actual_output_ratio(
        _requested_output_ratio,
        requested,
        granted
    )
    _consumption_per_second = granted / maxf(_pending_delta, 0.000001)
    _trace_rate_limited(
        "LISTENER energy_grant %.3f/%.3f u -> motor output %.1f%%" % [
            granted,
            requested,
            _actual_output_ratio * 100.0,
        ],
        _actual_output_ratio
    )
    _publish_output()


func get_required_power_type() -> StringName:
    return required_power_type


func get_actual_output_ratio() -> float:
    return _actual_output_ratio


func get_requested_output_ratio() -> float:
    return _requested_output_ratio


func get_consumption_per_second() -> float:
    return _consumption_per_second


func get_snapshot() -> Dictionary:
    return {
        "component_id": component_id,
        "required_power_type": required_power_type,
        "requested_output_ratio": _requested_output_ratio,
        "actual_output_ratio": _actual_output_ratio,
        "consumption_per_second": _consumption_per_second,
        "max_consumption_per_second": max_consumption_per_second,
    }


func _publish_output() -> void:
    if _audio != null:
        _audio.set_intensity(_actual_output_ratio)
    output_changed.emit(
        _requested_output_ratio,
        _actual_output_ratio,
        _consumption_per_second
    )
    status_changed.emit(get_snapshot())


func _build_visual() -> void:
    var body := MeshInstance3D.new()
    body.name = "EngineBody"
    body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    var body_mesh := CylinderMesh.new()
    body_mesh.top_radius = 0.42
    body_mesh.bottom_radius = 0.48
    body_mesh.height = 1.25
    body_mesh.radial_segments = 16
    body.mesh = body_mesh

    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = Color(0.10, 0.12, 0.15, 1.0)
    body_material.metallic = 0.90
    body_material.roughness = 0.24
    body.material_override = body_material
    add_child(body)

    var core := MeshInstance3D.new()
    core.name = "EngineCore"
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.30
    core_mesh.height = 0.60
    core.mesh = core_mesh

    var core_material := StandardMaterial3D.new()
    core_material.albedo_color = Color(0.03, 0.28, 0.46, 1.0)
    core_material.emission_enabled = true
    core_material.emission = Color(0.02, 0.30, 0.82, 1.0)
    core_material.emission_energy_multiplier = 2.4
    core_material.roughness = 0.18
    core.material_override = core_material
    add_child(core)


func _trace(message: String) -> void:
    if debug_events:
        print("[ENGINE:%s] %s" % [String(component_id), message])


func _trace_rate_limited(message: String, output_value: float) -> void:
    if not debug_events:
        return
    var now := Time.get_ticks_msec()
    if now - _last_log_ms < 650 and absf(output_value - _last_logged_output) < 0.12:
        return
    _last_log_ms = now
    _last_logged_output = output_value
    _trace(message)
