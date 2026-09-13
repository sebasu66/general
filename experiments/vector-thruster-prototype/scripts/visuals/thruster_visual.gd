class_name ThrusterVisual
extends Node3D

@export var mount_id: StringName = &"thruster"

var _flame: MeshInstance3D
var _flame_material: StandardMaterial3D


func _ready() -> void:
    _create_housing()
    _create_flame()


func set_output(local_direction: Vector3, thrust_ratio: float) -> void:
    var direction := local_direction.normalized()
    if direction.length_squared() < 0.001:
        direction = Vector3.UP

    basis = Basis(Quaternion(Vector3.UP, direction))

    var ratio := clampf(thrust_ratio, 0.0, 1.0)
    _flame.visible = ratio > 0.005

    var flame_length := lerpf(0.08, 2.2, ratio)
    var flame_width := lerpf(0.32, 0.52, ratio)
    _flame.scale = Vector3(flame_width, flame_length, flame_width)
    _flame.position = Vector3(0.0, -0.42 - flame_length * 0.5, 0.0)
    _flame_material.emission_energy_multiplier = lerpf(1.5, 8.0, ratio)


func _create_housing() -> void:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "Housing"

    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.24
    mesh.bottom_radius = 0.34
    mesh.height = 0.52
    mesh.radial_segments = 16
    mesh_instance.mesh = mesh

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.16, 0.19, 0.24, 1.0)
    material.metallic = 0.75
    material.roughness = 0.32
    mesh_instance.material_override = material

    add_child(mesh_instance)


func _create_flame() -> void:
    _flame = MeshInstance3D.new()
    _flame.name = "Flame"

    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.07
    mesh.bottom_radius = 0.20
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

    add_child(_flame)
    _flame.visible = false
