class_name PowerSourceLibrary
extends RefCounted


static func generated_energy(
        generation_per_second: float,
        sunlight_factor: float,
        delta: float
) -> float:
    return maxf(generation_per_second, 0.0) * clampf(sunlight_factor, 0.0, 1.0) * maxf(delta, 0.0)


static func recharge(current_energy: float, capacity: float, generated: float) -> float:
    return clampf(current_energy + maxf(generated, 0.0), 0.0, maxf(capacity, 0.001))


static func grant_energy(current_energy: float, requested: float) -> float:
    return minf(maxf(requested, 0.0), maxf(current_energy, 0.0))


static func battery_ratio(current_energy: float, capacity: float) -> float:
    return clampf(current_energy / maxf(capacity, 0.001), 0.0, 1.0)
