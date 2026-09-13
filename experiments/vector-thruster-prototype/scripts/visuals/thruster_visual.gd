class_name ThrusterVisual
extends Node3D

@export var mount_id: StringName = &"thruster"

var _gimbal: Node3D
var _flame: MeshInstance3D
var _flame_material: StandardMaterial3D


func _ready() -> void:
    _create_tower_housing()
    _create_gimbal_nozzle()
    _create_flame()


func set_output(local_direction: Vector3, thrust_ratio: float) -> void:
    var direction := local_direction.normalized()
    if direction.length_squared() < 0.001:
        direction = Vector3.UP

    _gimbal.basis = Basis(Quaternion(Vector3.UP, direction))

    var ratio := clampf(thrust_ratio, 0.0, 1.0)
    _flame.visible = ratio > 0.005

    var flame_length := lerpf(0.12, 2.8, ratio)
    var flame_width := lerpf(0.38, 0.62, ratio)
    _flame.scale = Vector3(flame_width, flame_length, flame_width)
    _flame.position = Vector3(0.0, -0.52 - flame_length * 0.5, 0.0)
    _flame_material.emission_energy_multiplier = lerpf(1.5, 9.5, ratio)


func _create_tower_housing() -> void:
    var tower := MeshInstance3D.new()
    tower.name = "TowerHousing"
    tower.position = Vector3(0.0, 0.42, 0.0)

    var tower_mesh := CylinderMesh.new()
    tower_mesh.top_radius = 0.30
    tower_mesh.bottom_radius = 0.54
    tower_mesh.height = 1.55
    tower_mesh.radial_segments = 4
    tower.mesh = tower_mesh

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.13, 0.17, 0.23, 1.0)
    material.metallic = 0.82
    material.roughness = 0.30
    tower.material_override = material
    add_child(tower)

    var shoulder := MeshInstance3D.new()
    shoulder.name = "ShoulderRing"
    shoulder.position = Vector3(0.0, -0.30, 0.0)

    var shoulder_mesh := CylinderMesh.new()
    shoulder_mesh.top_radius = 0.56
    shoulder_mesh.bottom_radius = 0.56
    shoulder_mesh.height = 0.18
    shoulder_mesh.radial_segments = 12
    shoulder.mesh = shoulder_mesh
    shoulder.material_override = material
    add_child(shoulder)


func _create_gimbal_nozzle() -> void:
    _gimbal = Node3D.new()
    _gimbal.name = "Gimbal"
    _gimbal.position = Vector3(0.0, -0.38, 0.0)
    add_child(_gimbal)

    var nozzle := MeshInstance3D.new()
    nozzle.name = "Nozzle"
    nozzle.position = Vector3(0.0, -0.22, 0.0)

    var nozzle_mesh := CylinderMesh.new()
    nozzle_mesh.top_radius = 0.28
    nozzle_mesh.bottom_radius = 0.48
    nozzle_mesh.height = 0.48
    nozzle_mesh.radial_segments = 12
    nozzle.mesh = nozzle_mesh

    var nozzle_material := StandardMaterial3D.new()
    nozzle_material.albedo_color = Color(0.07, 0.09, 0.12, 1.0)
    nozzle_material.metallic = 0.92
    nozzle_material.roughness = 0.22
    nozzle.material_override = nozzle_material
    _gimbal.add_child(nozzle)


func _create_flame() -> void:
    _flame = MeshInstance3D.new()
    _flame.name = "Flame"

    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.08
    mesh.bottom_radius = 0.22
    mesh.height = 1.0
    mesh.radial_segments = 12
    _flame.mesh = mesh

    _flame_material = StandardMaterial3D.new()
    _flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _flame_material.albedo_color = Color(0.24, 0.72, 1.0, 1.0)
    _flame_material.emission_enabled = true
    _flame_material.emission = Color(0.08, 0.48, 1.0, 1.0)
    _flame_material.emission_energy_multiplier = 4.0
    _flame.material_override = _flame_material

    _gimbal.add_child(_flame)
    _flame.visible = false
