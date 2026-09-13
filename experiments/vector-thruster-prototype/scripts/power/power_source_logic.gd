class_name PowerSourceLogic
extends Node3D

signal energy_granted(consumer_id: StringName, requested: float, granted: float)
signal status_changed(snapshot: Dictionary)

@export var component_id: StringName = &"solar_battery"
@export var power_type: StringName = &"electric"
@export var battery_capacity: float = 1200.0
@export var starting_charge_ratio: float = 1.0
@export var solar_generation_per_second: float = 58.0
@export_range(0.0, 1.0, 0.01) var sunlight_factor: float = 1.0
@export var debug_events: bool = true

var _current_energy: float = 0.0
var _generation_per_second: float = 0.0
var _consumption_per_second: float = 0.0
var _last_tick_delta: float = 1.0 / 60.0
var _last_log_ms: int = 0
var _last_logged_ratio: float = -1.0


func _ready() -> void:
    _current_energy = clampf(starting_charge_ratio, 0.0, 1.0) * battery_capacity
    _build_visual()
    _trace("READY fuente solar + bateria %.0f u type=%s" % [battery_capacity, String(power_type)])
    _publish_status()


func can_supply(requested_power_type: StringName) -> bool:
    return requested_power_type == power_type


func listen_power_tick(delta: float) -> void:
    _last_tick_delta = maxf(delta, 0.000001)
    var generated := PowerSourceLibrary.generated_energy(
        solar_generation_per_second,
        sunlight_factor,
        _last_tick_delta
    )
    _current_energy = PowerSourceLibrary.recharge(
        _current_energy,
        battery_capacity,
        generated
    )
    _generation_per_second = generated / _last_tick_delta
    _consumption_per_second = 0.0
    _publish_status()


func listen_energy_request(consumer_id: StringName, requested: float) -> void:
    var granted := PowerSourceLibrary.grant_energy(_current_energy, requested)
    _current_energy -= granted
    _consumption_per_second += granted / maxf(_last_tick_delta, 0.000001)
    _trace_rate_limited(
        "LISTENER energy_request %s %.3f u -> TRIGGER energy_granted %.3f u" % [
            String(consumer_id),
            requested,
            granted,
        ]
    )
    energy_granted.emit(consumer_id, requested, granted)
    _publish_status()


func get_battery_ratio() -> float:
    return PowerSourceLibrary.battery_ratio(_current_energy, battery_capacity)


func get_snapshot() -> Dictionary:
    return {
        "component_id": component_id,
        "power_type": power_type,
        "current_energy": _current_energy,
        "capacity": battery_capacity,
        "battery_ratio": get_battery_ratio(),
        "solar_generation_per_second": _generation_per_second,
        "configured_solar_generation_per_second": solar_generation_per_second,
        "sunlight_factor": sunlight_factor,
        "consumption_per_second": _consumption_per_second,
        "net_per_second": _generation_per_second - _consumption_per_second,
    }


func _publish_status() -> void:
    status_changed.emit(get_snapshot())


func _build_visual() -> void:
    var battery := MeshInstance3D.new()
    battery.name = "BatteryPack"
    battery.position = Vector3(0.0, -0.18, 0.0)
    var battery_mesh := BoxMesh.new()
    battery_mesh.size = Vector3(1.10, 0.42, 0.82)
    battery.mesh = battery_mesh

    var battery_material := StandardMaterial3D.new()
    battery_material.albedo_color = Color(0.12, 0.16, 0.13, 1.0)
    battery_material.metallic = 0.62
    battery_material.roughness = 0.34
    battery.material_override = battery_material
    add_child(battery)

    var solar_panel := MeshInstance3D.new()
    solar_panel.name = "SolarCollector"
    solar_panel.position = Vector3(0.0, 0.15, 0.0)
    var panel_mesh := BoxMesh.new()
    panel_mesh.size = Vector3(1.45, 0.08, 1.15)
    solar_panel.mesh = panel_mesh

    var panel_material := StandardMaterial3D.new()
    panel_material.albedo_color = Color(0.025, 0.10, 0.17, 1.0)
    panel_material.metallic = 0.72
    panel_material.roughness = 0.16
    panel_material.emission_enabled = true
    panel_material.emission = Color(0.01, 0.06, 0.16, 1.0)
    panel_material.emission_energy_multiplier = 0.7
    solar_panel.material_override = panel_material
    add_child(solar_panel)


func _trace(message: String) -> void:
    if debug_events:
        print("[POWER:%s] %s" % [String(component_id), message])


func _trace_rate_limited(message: String) -> void:
    if not debug_events:
        return
    var now := Time.get_ticks_msec()
    var ratio := get_battery_ratio()
    if now - _last_log_ms < 700 and absf(ratio - _last_logged_ratio) < 0.05:
        return
    _last_log_ms = now
    _last_logged_ratio = ratio
    _trace(message + " | battery %.1f%%" % (ratio * 100.0))
