extends Node3D

const BASE_CONTENT_SIZE := Vector2i(1600, 900)

@onready var space_world: SpaceWorld = $SpaceWorld
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
    _place_vehicle_after_world_generation()
    follow_camera.target = vehicle
    follow_camera.snap_to_target()
    hud.bind(vehicle)
    engine_ui.bind(vehicle.get_engine_component())
    power_ui.bind(vehicle.get_power_source_component())
    computer_ui.bind(vehicle.get_ship_computer())


func _place_vehicle_after_world_generation() -> void:
    space_world.ensure_generated()
    var spawn_transform := space_world.get_safe_spawn_transform()

    vehicle.freeze = true
    vehicle.global_transform = spawn_transform
    vehicle.linear_velocity = Vector3.ZERO
    vehicle.angular_velocity = Vector3.ZERO
    vehicle.configure_spawn_transform(spawn_transform)
    vehicle.reset_physics_interpolation()
    vehicle.freeze = false

    print(
        "[WORLD] space world ready -> vehicle spawn y=%.2f starter asteroid radius=%.1f" % [
            spawn_transform.origin.y,
            space_world.get_starter_asteroid_radius(),
        ]
    )


func _configure_window_scaling() -> void:
    var window := get_window()
    window.unresizable = false
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = BASE_CONTENT_SIZE


func _configure_environment() -> void:
    world_environment.environment = space_world.build_environment()
