class_name ThrusterUI
extends RefCounted

## Placeholder UI adapter for an individual nozzle component.
## No permanent per-nozzle HUD is shown yet; the ship computer terminal is the
## current presentation surface. Keeping this adapter separate establishes the
## component contract for future local nozzle controls/panels.


static func format_status(snapshot: Dictionary) -> String:
    return "%s  %.0f%%  %.0f N  %.1f deg" % [
        String(snapshot.get("id", &"?")),
        float(snapshot.get("throttle", 0.0)) * 100.0,
        float(snapshot.get("thrust", 0.0)),
        float(snapshot.get("gimbal_degrees", 0.0)),
    ]
