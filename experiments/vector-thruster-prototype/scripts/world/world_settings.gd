class_name WorldSettings
extends Resource

@export_group("Generation")
@export var world_seed: int = 47291
@export_range(100.0, 10000.0, 10.0) var field_radius: float = 1800.0
@export_range(1, 2000, 1) var asteroid_count: int = 340
@export_range(2.0, 120.0, 1.0) var asteroid_min_radius: float = 8.0
@export_range(4.0, 220.0, 1.0) var asteroid_max_radius: float = 72.0
@export_range(16.0, 180.0, 1.0) var starter_asteroid_radius: float = 42.0
@export_range(2.0, 40.0, 0.5) var spawn_clearance: float = 8.0

@export_group("Streaming / LOD")
@export_range(64.0, 1024.0, 16.0) var sector_size: float = 320.0
@export_range(1, 8, 1) var active_sector_radius: int = 2
@export_range(50.0, 1200.0, 10.0) var detailed_distance: float = 360.0
@export_range(200.0, 5000.0, 50.0) var far_visibility_distance: float = 2200.0

@export_group("Voxel Asteroids")
@export_range(0.5, 8.0, 0.25) var voxel_cell_size: float = 2.5
@export_range(8, 64, 1) var voxel_resolution: int = 24
@export_range(0.0, 1.0, 0.01) var voxel_surface_noise: float = 0.24

@export_group("Gravity")
@export_range(0.1, 30.0, 0.1) var asteroid_surface_gravity: float = 5.2
@export_range(1.1, 12.0, 0.1) var gravity_influence_multiplier: float = 4.5
@export_range(0.01, 2.0, 0.01) var zero_gravity_threshold: float = 0.15

@export_group("Stars")
@export_range(100, 6000, 10) var star_count: int = 1600
@export_range(200.0, 5000.0, 10.0) var star_inner_radius: float = 900.0
@export_range(500.0, 10000.0, 10.0) var star_outer_radius: float = 2600.0
