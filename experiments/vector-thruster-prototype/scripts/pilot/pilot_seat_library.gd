class_name PilotSeatLibrary
extends RefCounted


static func controls_changed_significantly(
        previous: PilotInputState,
        current: PilotInputState,
        threshold: float = 0.10
) -> bool:
    if absf(previous.lift - current.lift) >= threshold:
        return true
    if previous.move.distance_to(current.move) >= threshold:
        return true
    if absf(previous.yaw - current.yaw) >= threshold:
        return true
    return false


static func format_controls(state: PilotInputState) -> String:
    return "lift %.0f%% move(%+.2f,%+.2f) yaw%+.2f" % [
        state.lift * 100.0,
        state.move.x,
        state.move.y,
        state.yaw,
    ]
