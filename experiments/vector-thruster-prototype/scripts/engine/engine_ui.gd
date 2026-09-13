class_name EngineUI
extends CanvasLayer

var _engine: EngineLogic
var _bar: ProgressBar
var _label: Label


func _ready() -> void:
    layer = 6
    _build_ui()


func bind(engine: EngineLogic) -> void:
    _engine = engine


func _process(_delta: float) -> void:
    if _engine == null:
        return
    var snapshot := _engine.get_snapshot()
    var requested := float(snapshot.get("requested_output_ratio", 0.0))
    var actual := float(snapshot.get("actual_output_ratio", 0.0))
    var consumption := float(snapshot.get("consumption_per_second", 0.0))
    _bar.value = actual * 100.0
    _label.text = "MOTOR  %5.1f%%   pedido %5.1f%%   consumo %.1f u/s" % [
        actual * 100.0,
        requested * 100.0,
        consumption,
    ]


func _build_ui() -> void:
    var panel := PanelContainer.new()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.offset_left = -470.0
    panel.offset_right = -18.0
    panel.offset_top = 18.0
    panel.offset_bottom = 106.0
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 5)
    margin.add_child(stack)

    _label = Label.new()
    _label.text = "MOTOR"
    _label.add_theme_font_size_override("font_size", 17)
    stack.add_child(_label)

    _bar = ProgressBar.new()
    _bar.min_value = 0.0
    _bar.max_value = 100.0
    _bar.show_percentage = false
    _bar.custom_minimum_size = Vector2(420.0, 22.0)
    stack.add_child(_bar)
