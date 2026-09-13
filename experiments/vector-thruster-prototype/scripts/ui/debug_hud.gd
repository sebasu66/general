class_name DebugHUD
extends CanvasLayer

var _vehicle: VehicleLogic
var _metrics_label: Label
var _status_label: Label


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

    _metrics_label.text = _format_metrics(snapshot)
    _status_label.text = "STABILIZER: %s" % ("ON" if snapshot.get("stabilizer_enabled", false) else "OFF")


func _build_ui() -> void:
    var panel := PanelContainer.new()
    panel.name = "MetricsPanel"
    panel.position = Vector2(14.0, 14.0)
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    margin.add_child(stack)

    var title := Label.new()
    title.text = "VECTOR THRUSTER PROTOTYPE — GODOT 4.7.2 / JOLT"
    title.add_theme_font_size_override("font_size", 17)
    stack.add_child(title)

    _status_label = Label.new()
    _status_label.text = "STABILIZER: ON"
    _status_label.add_theme_font_size_override("font_size", 16)
    stack.add_child(_status_label)

    _metrics_label = Label.new()
    _metrics_label.custom_minimum_size = Vector2(560.0, 0.0)
    _metrics_label.add_theme_font_size_override("font_size", 14)
    _metrics_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(_metrics_label)

    var controls := Label.new()
    controls.text = "RT/Space lift   LS/WASD vector   RS-X/QE yaw   A/F stabilizer   Y/R reset   1-4 individual boost"
    controls.position = Vector2(14.0, 850.0)
    controls.add_theme_font_size_override("font_size", 15)
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(controls)


func _format_metrics(snapshot: Dictionary) -> String:
    var velocity: Vector3 = snapshot.get("linear_velocity", Vector3.ZERO)
    var angular_velocity: Vector3 = snapshot.get("angular_velocity", Vector3.ZERO)
    var orientation: Vector3 = snapshot.get("orientation_degrees", Vector3.ZERO)
    var move_input: Vector2 = snapshot.get("move_input", Vector2.ZERO)
    var level_error: Vector3 = snapshot.get("stabilizer_level_error", Vector3.ZERO)
    var stabilizer_command: Vector2 = snapshot.get("stabilizer_command", Vector2.ZERO)

    var text := ""
    text += "Mass              %7.1f kg\n" % float(snapshot.get("mass", 0.0))
    text += "Gravity           %7.2f m/s²   weight %7.1f N\n" % [
        float(snapshot.get("gravity_acceleration", 0.0)),
        float(snapshot.get("gravity_force", 0.0)),
    ]
    text += "Hover estimate    %7.1f %% throttle\n" % (float(snapshot.get("hover_throttle_estimate", 0.0)) * 100.0)
    text += "Lift input        %7.1f %%\n" % (float(snapshot.get("lift_input", 0.0)) * 100.0)
    text += "Move / yaw        (%+.2f, %+.2f) / %+.2f\n" % [move_input.x, move_input.y, float(snapshot.get("yaw_input", 0.0))]
    text += "Speed             %7.2f m/s   vertical %+.2f m/s\n" % [float(snapshot.get("speed", 0.0)), float(snapshot.get("vertical_speed", 0.0))]
    text += "Velocity          (%+.2f, %+.2f, %+.2f)\n" % [velocity.x, velocity.y, velocity.z]
    text += "Angular vel       (%+.2f, %+.2f, %+.2f) rad/s\n" % [angular_velocity.x, angular_velocity.y, angular_velocity.z]
    text += "Orientation       (%+.1f, %+.1f, %+.1f) deg\n" % [orientation.x, orientation.y, orientation.z]
    text += "Thrust actual     %7.1f / %7.1f N\n" % [
        float(snapshot.get("total_actual_thrust", 0.0)),
        float(snapshot.get("total_available_thrust", 0.0)),
    ]
    text += "Stab error        (%+.3f, %+.3f, %+.3f)\n" % [level_error.x, level_error.y, level_error.z]
    text += "Stab command      (%+.2f, %+.2f) strength %.2f\n\n" % [
        stabilizer_command.x,
        stabilizer_command.y,
        float(snapshot.get("stabilizer_strength", 0.0)),
    ]
    text += "THRUSTER     THROTTLE    THRUST       STAB      GIMBAL      DIR (local)\n"

    var thrusters: Array = snapshot.get("thrusters", [])
    for item: Dictionary in thrusters:
        var direction: Vector3 = item.get("direction", Vector3.UP)
        text += "%-9s    %6.1f%%   %6.1f/%4.0f N   %+6.1f%%    %5.1f°    (%+.2f,%+.2f,%+.2f)\n" % [
            String(item.get("id", &"?")),
            float(item.get("effective_throttle", 0.0)) * 100.0,
            float(item.get("thrust", 0.0)),
            float(item.get("max_thrust", 0.0)),
            float(item.get("stabilization", 0.0)) * 100.0,
            float(item.get("gimbal_degrees", 0.0)),
            direction.x,
            direction.y,
            direction.z,
        ]

    return text
