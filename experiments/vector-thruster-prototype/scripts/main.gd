extends Node3D

const BASE_CONTENT_SIZE := Vector2i(1600, 900)

@onready var terrain: ProceduralTerrain = $Terrain
@onready var vehicle: VehicleLogic = $Vehicle
@onready var follow_camera: PrototypeFollowCamera = $FollowCamera
@onready var hud: DebugHUD = $HUD
@onready var engine_ui: EngineUI = $EngineUI
@onready var power_ui: PowerSourceUI = $PowerUI
@onready var computer_ui: ShipComputerUI = $ComputerUI
@onready var world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
    PilotInput.ensure_actions()
    _configure_window_scaling()
    _configure_environment()
    _place_vehicle_after_terrain_generation()
    follow_camera.target = vehicle
    follow_camera.snap_to_target()
    hud.bind(vehicle)
    engine_ui.bind(vehicle.get_engine_component())
    power_ui.bind(vehicle.get_power_source_component())
    computer_ui.bind(vehicle.get_ship_computer())


func _place_vehicle_after_terrain_generation() -> void:
    terrain.ensure_generated()
    var spawn_position := terrain.get_safe_spawn_position()

    vehicle.freeze = true
    vehicle.global_position = spawn_position
    vehicle.linear_velocity = Vector3.ZERO
    vehicle.angular_velocity = Vector3.ZERO
    vehicle.configure_spawn_transform(vehicle.global_transform)
    vehicle.reset_physics_interpolation()
    vehicle.freeze = false

    print(
        "[WORLD] terrain ready -> vehicle positioned at %.2f m above world origin (terrain %.2f + clearance %.2f)" % [
            spawn_position.y,
            terrain.get_height_at(0.0, 0.0),
            terrain.spawn_clearance,
        ]
    )


func _configure_window_scaling() -> void:
    var window := get_window()
    window.unresizable = false
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = BASE_CONTENT_SIZE


func _configure_environment() -> void:
    var sky_material := PhysicalSkyMaterial.new()
    sky_material.turbidity = 5.5
    sky_material.ground_color = Color(0.08, 0.065, 0.05, 1.0)
    sky_material.energy_multiplier = 0.82

    var sky := Sky.new()
    sky.sky_material = sky_material

    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.34
    environment.ambient_light_sky_contribution = 0.62
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.ssao_enabled = true
    environment.ssao_radius = 2.2
    environment.ssao_intensity = 2.2
    environment.ssil_enabled = true
    environment.ssil_intensity = 0.7
    environment.volumetric_fog_enabled = true
    environment.volumetric_fog_density = 0.004
    world_environment.environment = environment
