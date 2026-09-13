class_name DebugHUD
extends CanvasLayer

var _vehicle: VehicleLogic
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

    var stabilizer_text := "ON" if snapshot.get("stabilizer_enabled", false) else "OFF"
    var hover_text := "OFF"
    if snapshot.get("hover_enabled", false):
        hover_text = "ON @ %.1f m" % float(snapshot.get("hover_target_altitude", 0.0))

    _status_label.text = "STABILIZER %s   HOVER %s   BATTERY %.0f%%   MOTOR %.0f%%" % [
        stabilizer_text,
        hover_text,
        float(snapshot.get("battery_ratio", 0.0)) * 100.0,
        float(snapshot.get("engine_output_ratio", 0.0)) * 100.0,
    ]


func _build_ui() -> void:
    var panel := PanelContainer.new()
    panel.position = Vector2(18.0, 18.0)
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    _status_label = Label.new()
    _status_label.text = "STABILIZER ON   HOVER OFF"
    _status_label.add_theme_font_size_override("font_size", 19)
    margin.add_child(_status_label)

    var controls := Label.new()
    controls.text = "RT/Space lift   LS/WASD vector   RS-X/QE yaw   A/F stabilizer   B/H hover   T/X ship computer   Y/R reset"
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.offset_left = 18.0
    controls.offset_top = -42.0
    controls.offset_right = 1560.0
    controls.offset_bottom = -12.0
    controls.add_theme_font_size_override("font_size", 17)
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(controls)
