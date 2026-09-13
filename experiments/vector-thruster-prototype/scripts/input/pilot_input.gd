class_name PilotInput
extends RefCounted

const LIFT: StringName = &"vehicle_lift"
const MOVE_LEFT: StringName = &"vehicle_move_left"
const MOVE_RIGHT: StringName = &"vehicle_move_right"
const MOVE_FORWARD: StringName = &"vehicle_move_forward"
const MOVE_BACK: StringName = &"vehicle_move_back"
const YAW_LEFT: StringName = &"vehicle_yaw_left"
const YAW_RIGHT: StringName = &"vehicle_yaw_right"
const STABILIZER_TOGGLE: StringName = &"vehicle_stabilizer_toggle"
const RESET: StringName = &"vehicle_reset"
const THRUSTER_1: StringName = &"vehicle_thruster_1"
const THRUSTER_2: StringName = &"vehicle_thruster_2"
const THRUSTER_3: StringName = &"vehicle_thruster_3"
const THRUSTER_4: StringName = &"vehicle_thruster_4"


static func ensure_actions() -> void:
    _ensure_action_with_defaults(LIFT, 0.05, [_key_event(KEY_SPACE), _axis_event(JOY_AXIS_TRIGGER_RIGHT, 1.0)])

    _ensure_action_with_defaults(MOVE_LEFT, 0.18, [_key_event(KEY_A), _axis_event(JOY_AXIS_LEFT_X, -1.0)])
    _ensure_action_with_defaults(MOVE_RIGHT, 0.18, [_key_event(KEY_D), _axis_event(JOY_AXIS_LEFT_X, 1.0)])
    _ensure_action_with_defaults(MOVE_FORWARD, 0.18, [_key_event(KEY_W), _axis_event(JOY_AXIS_LEFT_Y, -1.0)])
    _ensure_action_with_defaults(MOVE_BACK, 0.18, [_key_event(KEY_S), _axis_event(JOY_AXIS_LEFT_Y, 1.0)])

    _ensure_action_with_defaults(YAW_LEFT, 0.18, [_key_event(KEY_Q), _axis_event(JOY_AXIS_RIGHT_X, -1.0)])
    _ensure_action_with_defaults(YAW_RIGHT, 0.18, [_key_event(KEY_E), _axis_event(JOY_AXIS_RIGHT_X, 1.0)])

    _ensure_action_with_defaults(STABILIZER_TOGGLE, 0.2, [_key_event(KEY_F), _button_event(JOY_BUTTON_A)])
    _ensure_action_with_defaults(RESET, 0.2, [_key_event(KEY_R), _button_event(JOY_BUTTON_Y)])

    _ensure_action_with_defaults(THRUSTER_1, 0.2, [_key_event(KEY_1)])
    _ensure_action_with_defaults(THRUSTER_2, 0.2, [_key_event(KEY_2)])
    _ensure_action_with_defaults(THRUSTER_3, 0.2, [_key_event(KEY_3)])
    _ensure_action_with_defaults(THRUSTER_4, 0.2, [_key_event(KEY_4)])


static func read_continuous() -> PilotInputState:
    var state := PilotInputState.new()
    state.lift = Input.get_action_strength(LIFT)
    state.move = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)
    state.yaw = Input.get_axis(YAW_LEFT, YAW_RIGHT)
    state.manual_thruster_boosts[0] = Input.get_action_strength(THRUSTER_1)
    state.manual_thruster_boosts[1] = Input.get_action_strength(THRUSTER_2)
    state.manual_thruster_boosts[2] = Input.get_action_strength(THRUSTER_3)
    state.manual_thruster_boosts[3] = Input.get_action_strength(THRUSTER_4)
    return state


static func _ensure_action_with_defaults(action: StringName, deadzone: float, events: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, deadzone)
    else:
        InputMap.action_set_deadzone(action, deadzone)

    if not InputMap.action_get_events(action).is_empty():
        return

    for event: InputEvent in events:
        InputMap.action_add_event(action, event)


static func _key_event(keycode: int) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    return event


static func _axis_event(axis: int, value: float) -> InputEventJoypadMotion:
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = value
    return event


static func _button_event(button: int) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.button_index = button
    return event
