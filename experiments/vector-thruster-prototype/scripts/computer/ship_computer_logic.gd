class_name ShipComputerLogic
extends Node3D

signal pilot_controls_dispatched(state: PilotInputState)
signal mode_command_dispatched(command: StringName)
signal terminal_toggle_dispatched
signal thruster_command_dispatched(command: ThrusterCommand)
signal engine_power_request_dispatched(requested_ratio: float, delta: float)
signal power_tick_dispatched(delta: float)
signal energy_request_dispatched(consumer_id: StringName, amount: float)
signal energy_grant_dispatched(consumer_id: StringName, requested: float, granted: float)
signal status_changed(snapshot: Dictionary)

@export var component_id: StringName = &"ship_computer"
@export var debug_events: bool = true

var _latest_pilot_input := PilotInputState.new()
var _engine_snapshot: Dictionary = {}
var _power_snapshot: Dictionary = {}
var _thruster_snapshots: Dictionary = {}
var _connections: Array[String] = []
var _last_dispatch_log_ms: int = 0


func _ready() -> void:
    _build_visual()
    _trace("READY central event router")


func configure(
        pilot_seat: PilotSeatLogic,
        engine: EngineLogic,
        power_source: PowerSourceLogic,
        thrusters: Array[ThrusterLogic]
) -> void:
    _connections.clear()

    _connect_once(pilot_seat.controls_changed, _on_pilot_controls_triggered)
    _connect_once(pilot_seat.stabilizer_toggle_requested, _on_stabilizer_toggle_triggered)
    _connect_once(pilot_seat.hover_toggle_requested, _on_hover_toggle_triggered)
    _connect_once(pilot_seat.reset_requested, _on_reset_triggered)
    _connect_once(pilot_seat.terminal_toggle_requested, _on_terminal_toggle_triggered)
    _connections.append("PilotSeat.controls -> ShipComputer -> flight controller")
    _connections.append("PilotSeat.mode buttons -> ShipComputer -> vehicle modes")

    _connect_once(engine_power_request_dispatched, engine.listen_engine_power_request)
    _connect_once(engine.output_changed, _on_engine_output_changed)
    _connect_once(engine.status_changed, _on_engine_status_changed)
    _connections.append("ShipComputer.engine request -> MainEngine")

    _connect_once(power_tick_dispatched, power_source.listen_power_tick)
    _connect_once(power_source.status_changed, _on_power_status_changed)

    var required_power_type := engine.get_required_power_type()
    if power_source.can_supply(required_power_type):
        _connect_once(engine.energy_requested, _on_engine_energy_requested)
        _connect_once(energy_request_dispatched, power_source.listen_energy_request)
        _connect_once(power_source.energy_granted, _on_power_energy_granted)
        _connect_once(energy_grant_dispatched, engine.listen_energy_grant)
        _connections.append(
            "MainEngine[%s].energy request -> ShipComputer -> SolarBattery[%s]" % [
                String(required_power_type),
                String(power_source.power_type),
            ]
        )
        _connections.append("SolarBattery.energy grant -> ShipComputer -> MainEngine")
    else:
        push_warning(
            "ShipComputer cannot connect MainEngine power type '%s' to source type '%s'." % [
                String(required_power_type),
                String(power_source.power_type),
            ]
        )

    for thruster: ThrusterLogic in thrusters:
        _connect_once(thruster_command_dispatched, thruster.listen_thruster_command)
        _connect_once(thruster.status_changed, _on_thruster_status_changed)
        _connections.append("ShipComputer.control -> Nozzle[%s]" % String(thruster.mount_id))

    _trace("CONNECT complete: %d routed links" % _connections.size())
    for connection: String in _connections:
        _trace("CONNECT %s" % connection)
    _publish_status()


func tick_power_system(delta: float) -> void:
    power_tick_dispatched.emit(delta)


func sample_pilot_from(seat: PilotSeatLogic) -> PilotInputState:
    seat.sample_controls()
    return _latest_pilot_input


func request_engine_power(requested_ratio: float, delta: float) -> float:
    _trace_dispatch_rate_limited(
        "DISPATCH engine_power_request %.1f%%" % (requested_ratio * 100.0)
    )
    engine_power_request_dispatched.emit(requested_ratio, delta)
    return float(_engine_snapshot.get("actual_output_ratio", 0.0))


func route_thruster_command(command: ThrusterCommand) -> void:
    thruster_command_dispatched.emit(command)


func get_latest_pilot_input() -> PilotInputState:
    return _latest_pilot_input


func get_engine_supply_fraction(requested_ratio: float) -> float:
    if requested_ratio <= 0.000001:
        return 1.0
    var actual := float(_engine_snapshot.get("actual_output_ratio", 0.0))
    return clampf(actual / requested_ratio, 0.0, 1.0)


func get_snapshot() -> Dictionary:
    var thruster_list: Array[Dictionary] = []
    var ids: Array = _thruster_snapshots.keys()
    ids.sort()
    for id: Variant in ids:
        var item: Dictionary = _thruster_snapshots[id]
        thruster_list.append(item.duplicate(true))

    return {
        "component_id": component_id,
        "engine": _engine_snapshot.duplicate(true),
        "power": _power_snapshot.duplicate(true),
        "thrusters": thruster_list,
        "connections": _connections.duplicate(),
    }


func _on_pilot_controls_triggered(state: PilotInputState) -> void:
    _latest_pilot_input = state
    pilot_controls_dispatched.emit(state)


func _on_stabilizer_toggle_triggered() -> void:
    _trace("LISTENER pilot stabilizer toggle -> DISPATCH mode stabilizer")
    mode_command_dispatched.emit(&"stabilizer_toggle")


func _on_hover_toggle_triggered() -> void:
    _trace("LISTENER pilot hover toggle -> DISPATCH mode hover")
    mode_command_dispatched.emit(&"hover_toggle")


func _on_reset_triggered() -> void:
    _trace("LISTENER pilot reset -> DISPATCH mode reset")
    mode_command_dispatched.emit(&"reset")


func _on_terminal_toggle_triggered() -> void:
    _trace("LISTENER pilot terminal toggle -> DISPATCH terminal_toggle")
    terminal_toggle_dispatched.emit()


func _on_engine_energy_requested(consumer_id: StringName, amount: float) -> void:
    _trace_dispatch_rate_limited(
        "LISTENER engine energy request %.3f u -> DISPATCH power request" % amount
    )
    energy_request_dispatched.emit(consumer_id, amount)


func _on_power_energy_granted(
        consumer_id: StringName,
        requested: float,
        granted: float
) -> void:
    energy_grant_dispatched.emit(consumer_id, requested, granted)


func _on_engine_output_changed(
        requested_ratio: float,
        actual_ratio: float,
        consumption_per_second: float
) -> void:
    _engine_snapshot["requested_output_ratio"] = requested_ratio
    _engine_snapshot["actual_output_ratio"] = actual_ratio
    _engine_snapshot["consumption_per_second"] = consumption_per_second
    _publish_status()


func _on_engine_status_changed(snapshot: Dictionary) -> void:
    _engine_snapshot = snapshot.duplicate(true)
    _publish_status()


func _on_power_status_changed(snapshot: Dictionary) -> void:
    _power_snapshot = snapshot.duplicate(true)
    _publish_status()


func _on_thruster_status_changed(
        mount_id: StringName,
        throttle: float,
        thrust: float,
        gimbal_degrees: float
) -> void:
    _thruster_snapshots[mount_id] = {
        "id": mount_id,
        "throttle": throttle,
        "thrust": thrust,
        "gimbal_degrees": gimbal_degrees,
    }
    _publish_status()


func _publish_status() -> void:
    status_changed.emit(get_snapshot())


func _connect_once(source_signal: Signal, callable: Callable) -> void:
    if not source_signal.is_connected(callable):
        source_signal.connect(callable)


func _build_visual() -> void:
    var terminal := MeshInstance3D.new()
    terminal.name = "ComputerTerminal"
    terminal.position = Vector3(0.0, 0.0, 0.0)
    var terminal_mesh := BoxMesh.new()
    terminal_mesh.size = Vector3(0.72, 0.52, 0.18)
    terminal.mesh = terminal_mesh

    var terminal_material := StandardMaterial3D.new()
    terminal_material.albedo_color = Color(0.025, 0.08, 0.10, 1.0)
    terminal_material.emission_enabled = true
    terminal_material.emission = Color(0.01, 0.35, 0.28, 1.0)
    terminal_material.emission_energy_multiplier = 1.4
    terminal_material.roughness = 0.22
    terminal.material_override = terminal_material
    add_child(terminal)


func _trace(message: String) -> void:
    if debug_events:
        print("[COMPUTER:%s] %s" % [String(component_id), message])


func _trace_dispatch_rate_limited(message: String) -> void:
    if not debug_events:
        return
    var now := Time.get_ticks_msec()
    if now - _last_dispatch_log_ms < 700:
        return
    _last_dispatch_log_ms = now
    _trace(message)
