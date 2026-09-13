extends Node3D

@onready var vehicle: VehicleLogic = $Vehicle
@onready var follow_camera: PrototypeFollowCamera = $FollowCamera
@onready var hud: DebugHUD = $HUD
@onready var world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
    PilotInput.ensure_actions()
    _configure_environment()
    follow_camera.target = vehicle
    follow_camera.snap_to_target()
    hud.bind(vehicle)


func _configure_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.018, 0.026, 0.045, 1.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.42, 0.50, 0.64, 1.0)
    environment.ambient_light_energy = 0.68
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    world_environment.environment = environment
