class_name EngineLibrary
extends RefCounted


static func energy_required(
        requested_output_ratio: float,
        max_consumption_per_second: float,
        delta: float
) -> float:
    return clampf(requested_output_ratio, 0.0, 1.0) * maxf(max_consumption_per_second, 0.0) * maxf(delta, 0.0)


static func supply_fraction(requested_energy: float, granted_energy: float) -> float:
    if requested_energy <= 0.000001:
        return 1.0
    return clampf(granted_energy / requested_energy, 0.0, 1.0)


static func actual_output_ratio(
        requested_output_ratio: float,
        requested_energy: float,
        granted_energy: float
) -> float:
    return clampf(requested_output_ratio, 0.0, 1.0) * supply_fraction(requested_energy, granted_energy)
