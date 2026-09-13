class_name PilotSeatLogic
extends Node3D

signal controls_changed(state: PilotInputState)
signal stabilizer_toggle_requested
signal hover_toggle_requested
signal reset_requested
signal terminal_toggle_requested

@export var component_id: StringName = &"pilot_seat"
@export var debug_events: bool = true

var _previous_controls := PilotInputState.new()
var _last_log_ms: int = 0


func _ready() -> void:
    PilotInput.ensure_actions()
    _build_visual()
    _trace("READY asiento de piloto; controles conectables por eventos")


func sample_controls() -> PilotInputState:
    var current := PilotInput.read_continuous()
    controls_changed.emit(current)

    if PilotSeatLibrary.controls_changed_significantly(_previous_controls, current):
        var now := Time.get_ticks_msec()
        if now - _last_log_ms >= 350:
            _last_log_ms = now
            _trace("TRIGGER controls_changed -> %s" % PilotSeatLibrary.format_controls(current))

    _previous_controls = current
    return current


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return

    if event.is_action_pressed(PilotInput.STABILIZER_TOGGLE):
        _trace("TRIGGER stabilizer_toggle_requested")
        stabilizer_toggle_requested.emit()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed(PilotInput.HOVER_TOGGLE):
        _trace("TRIGGER hover_toggle_requested")
        hover_toggle_requested.emit()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed(PilotInput.RESET):
        _trace("TRIGGER reset_requested")
        reset_requested.emit()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed(PilotInput.COMPUTER_TOGGLE):
        _trace("TRIGGER terminal_toggle_requested")
        terminal_toggle_requested.emit()
        get_viewport().set_input_as_handled()


func _build_visual() -> void:
    var base := MeshInstance3D.new()
    base.name = "SeatBase"
    base.position = Vector3(0.0, 0.18, 0.18)
    var base_mesh := BoxMesh.new()
    base_mesh.size = Vector3(0.72, 0.34, 0.78)
    base.mesh = base_mesh

    var seat_material := StandardMaterial3D.new()
    seat_material.albedo_color = Color(0.08, 0.10, 0.12, 1.0)
    seat_material.metallic = 0.25
    seat_material.roughness = 0.62
    base.material_override = seat_material
    add_child(base)

    var back := MeshInstance3D.new()
    back.name = "SeatBack"
    back.position = Vector3(0.0, 0.68, 0.48)
    back.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
    var back_mesh := BoxMesh.new()
    back_mesh.size = Vector3(0.72, 0.82, 0.18)
    back.mesh = back_mesh
    back.material_override = seat_material
    add_child(back)

    var console := MeshInstance3D.new()
    console.name = "ControlConsole"
    console.position = Vector3(0.0, 0.48, -0.44)
    var console_mesh := BoxMesh.new()
    console_mesh.size = Vector3(0.88, 0.16, 0.38)
    console.mesh = console_mesh

    var console_material := StandardMaterial3D.new()
    console_material.albedo_color = Color(0.035, 0.12, 0.17, 1.0)
    console_material.emission_enabled = true
    console_material.emission = Color(0.01, 0.16, 0.28, 1.0)
    console_material.emission_energy_multiplier = 1.2
    console.material_override = console_material
    add_child(console)


func _trace(message: String) -> void:
    if debug_events:
        print("[PILOT:%s] %s" % [String(component_id), message])
