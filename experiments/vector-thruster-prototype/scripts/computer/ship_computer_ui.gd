class_name ShipComputerUI
extends CanvasLayer

var _computer: ShipComputerLogic
var _panel: PanelContainer
var _terminal_text: Label
var _visible: bool = false


func _ready() -> void:
    layer = 20
    _build_ui()
    _set_terminal_visible(false)


func bind(computer: ShipComputerLogic) -> void:
    _computer = computer
    if not computer.terminal_toggle_dispatched.is_connected(_on_terminal_toggle):
        computer.terminal_toggle_dispatched.connect(_on_terminal_toggle)


func _process(_delta: float) -> void:
    if not _visible or _computer == null:
        return
    _terminal_text.text = ShipComputerLibrary.build_terminal_text(_computer.get_snapshot())


func _on_terminal_toggle() -> void:
    _set_terminal_visible(not _visible)
    print("[COMPUTER_UI] LISTENER terminal_toggle -> visible=%s" % str(_visible))


func _set_terminal_visible(value: bool) -> void:
    _visible = value
    if _panel != null:
        _panel.visible = value


func _build_ui() -> void:
    _panel = PanelContainer.new()
    _panel.anchor_left = 0.08
    _panel.anchor_top = 0.08
    _panel.anchor_right = 0.92
    _panel.anchor_bottom = 0.90
    _panel.offset_left = 0.0
    _panel.offset_top = 0.0
    _panel.offset_right = 0.0
    _panel.offset_bottom = 0.0
    add_child(_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    _panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    margin.add_child(stack)

    var title := Label.new()
    title.text = "SHIP COMPUTER TERMINAL"
    title.add_theme_font_size_override("font_size", 24)
    stack.add_child(title)

    _terminal_text = Label.new()
    _terminal_text.text = "Waiting for component bus..."
    _terminal_text.add_theme_font_size_override("font_size", 18)
    _terminal_text.autowrap_mode = TextServer.AUTOWRAP_OFF
    _terminal_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(_terminal_text)
