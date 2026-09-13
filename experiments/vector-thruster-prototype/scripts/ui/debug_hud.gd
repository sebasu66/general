class_name DebugHUD
extends CanvasLayer

var _vehicle: VehicleLogic
var _status_label: Label
var _control_actions: Array[Label] = []
var _last_flight_mode: String = ""


func _ready() -> void:
    layer = 5
    _build_ui()


func bind(vehicle: VehicleLogic) -> void:
    _vehicle = vehicle


func _process(_delta: float) -> void:
    if _vehicle == null:
        return

    var snapshot := _vehicle.get_debug_snapshot()
    if snapshot.is_empty():
        return

    var flight_mode := String(snapshot.get("flight_mode", "SURFACE"))
    var stabilizer_text := "ON" if snapshot.get("stabilizer_enabled", false) else "OFF"
    var hover_text := "OFF"
    if snapshot.get("hover_enabled", false):
        hover_text = "ON @ %.1f m" % float(snapshot.get("hover_target_altitude", 0.0))

    var gravity_text := "ZERO-G"
    if snapshot.get("gravity_active", false):
        gravity_text = "GRAVITY %.2f m/s²" % float(snapshot.get("gravity_strength", 0.0))

    _status_label.text = "MODE %s   STABILIZER %s   HOVER %s   %s   BATTERY %.0f%%   MOTOR %.0f%%" % [
        flight_mode,
        stabilizer_text,
        hover_text,
        gravity_text,
        float(snapshot.get("battery_ratio", 0.0)) * 100.0,
        float(snapshot.get("engine_output_ratio", 0.0)) * 100.0,
    ]

    if flight_mode != _last_flight_mode:
        _last_flight_mode = flight_mode
        _update_control_legend(flight_mode)


func _build_ui() -> void:
    var status_panel := PanelContainer.new()
    status_panel.position = Vector2(18.0, 18.0)
    add_child(status_panel)

    var status_margin := MarginContainer.new()
    status_margin.add_theme_constant_override("margin_left", 14)
    status_margin.add_theme_constant_override("margin_right", 14)
    status_margin.add_theme_constant_override("margin_top", 10)
    status_margin.add_theme_constant_override("margin_bottom", 10)
    status_panel.add_child(status_margin)

    _status_label = Label.new()
    _status_label.text = "MODE SURFACE   STABILIZER ON   HOVER OFF   GRAVITY --"
    _status_label.add_theme_font_size_override("font_size", 19)
    status_margin.add_child(_status_label)

    var controls_panel := PanelContainer.new()
    controls_panel.anchor_top = 1.0
    controls_panel.anchor_bottom = 1.0
    controls_panel.offset_left = 18.0
    controls_panel.offset_top = -316.0
    controls_panel.offset_right = 430.0
    controls_panel.offset_bottom = -18.0
    add_child(controls_panel)

    var controls_margin := MarginContainer.new()
    controls_margin.add_theme_constant_override("margin_left", 16)
    controls_margin.add_theme_constant_override("margin_right", 16)
    controls_margin.add_theme_constant_override("margin_top", 12)
    controls_margin.add_theme_constant_override("margin_bottom", 12)
    controls_panel.add_child(controls_margin)

    var controls_stack := VBoxContainer.new()
    controls_stack.add_theme_constant_override("separation", 5)
    controls_margin.add_child(controls_stack)

    var title := Label.new()
    title.text = "GAMEPAD CONTROLS"
    title.add_theme_font_size_override("font_size", 20)
    controls_stack.add_child(title)

    _add_control_row(controls_stack, "[RT]", "Lift / engine throttle")
    _add_control_row(controls_stack, "[LS]", "Vector thrust / move")
    _add_control_row(controls_stack, "[RS ↔]", "Yaw left / right")
    _add_control_row(controls_stack, "[A]", "Attitude stabilizer ON / OFF")
    _add_control_row(controls_stack, "[B]", "Hover hold ON / OFF")
    _add_control_row(controls_stack, "[X]", "Ship computer terminal")
    _add_control_row(controls_stack, "[Y]", "Reset ship")


func _add_control_row(parent: VBoxContainer, button_text: String, action_text: String) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    parent.add_child(row)

    var button := Label.new()
    button.text = button_text
    button.custom_minimum_size = Vector2(78.0, 0.0)
    button.add_theme_font_size_override("font_size", 17)
    row.add_child(button)

    var action := Label.new()
    action.text = action_text
    action.add_theme_font_size_override("font_size", 16)
    row.add_child(action)
    _control_actions.append(action)


func _update_control_legend(flight_mode: String) -> void:
    if _control_actions.size() < 7:
        return

    if flight_mode == "SPACE":
        _control_actions[0].text = "Forward thrust · rear engines"
        _control_actions[1].text = "Pitch ↑↓ / roll ↔"
        _control_actions[2].text = "Yaw left / right"
        _control_actions[3].text = "Angular damping ON / OFF"
        _control_actions[4].text = "Hover unavailable in zero-G"
    else:
        _control_actions[0].text = "Lift / engine throttle"
        _control_actions[1].text = "Vector thrust / move"
        _control_actions[2].text = "Yaw left / right"
        _control_actions[3].text = "Attitude stabilizer ON / OFF"
        _control_actions[4].text = "Hover hold ON / OFF"

    _control_actions[5].text = "Ship computer terminal"
    _control_actions[6].text = "Reset ship"
