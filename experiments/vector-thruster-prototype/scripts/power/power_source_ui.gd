class_name PowerSourceUI
extends CanvasLayer

var _power: PowerSourceLogic
var _battery_bar: ProgressBar
var _solar_bar: ProgressBar
var _drain_bar: ProgressBar
var _summary_label: Label


func _ready() -> void:
    layer = 6
    _build_ui()


func bind(power_source: PowerSourceLogic) -> void:
    _power = power_source


func _process(_delta: float) -> void:
    if _power == null:
        return

    var snapshot := _power.get_snapshot()
    var battery_ratio := float(snapshot.get("battery_ratio", 0.0))
    var solar := float(snapshot.get("solar_generation_per_second", 0.0))
    var configured_solar := maxf(float(snapshot.get("configured_solar_generation_per_second", 1.0)), 0.001)
    var drain := float(snapshot.get("consumption_per_second", 0.0))
    var net := float(snapshot.get("net_per_second", 0.0))

    _battery_bar.value = battery_ratio * 100.0
    _solar_bar.value = clampf(solar / configured_solar, 0.0, 1.0) * 100.0
    _drain_bar.value = clampf(drain / 100.0, 0.0, 1.0) * 100.0
    _summary_label.text = "BATERIA %5.1f%%   SOL +%5.1f u/s   MOTOR -%5.1f u/s   NET %+5.1f" % [
        battery_ratio * 100.0,
        solar,
        drain,
        net,
    ]


func _build_ui() -> void:
    var panel := PanelContainer.new()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.offset_left = -470.0
    panel.offset_right = -18.0
    panel.offset_top = 116.0
    panel.offset_bottom = 270.0
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)
    margin.add_child(stack)

    _summary_label = Label.new()
    _summary_label.text = "FUENTE SOLAR / BATERIA"
    _summary_label.add_theme_font_size_override("font_size", 16)
    stack.add_child(_summary_label)

    _battery_bar = _add_bar_row(stack, "Carga")
    _solar_bar = _add_bar_row(stack, "Solar +")
    _drain_bar = _add_bar_row(stack, "Motor -")


func _add_bar_row(stack: VBoxContainer, label_text: String) -> ProgressBar:
    var row := HBoxContainer.new()
    stack.add_child(row)

    var label := Label.new()
    label.text = label_text
    label.custom_minimum_size = Vector2(78.0, 0.0)
    label.add_theme_font_size_override("font_size", 14)
    row.add_child(label)

    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(325.0, 18.0)
    row.add_child(bar)
    return bar
