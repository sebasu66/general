class_name ProceduralTerrain
extends StaticBody3D

@export var terrain_size: float = 260.0
@export_range(24, 160, 1) var resolution: int = 84
@export var height_scale: float = 7.5
@export var noise_frequency: float = 0.018
@export var detail_frequency: float = 0.055
@export var terrain_seed: int = 47291
@export_range(0, 120, 1) var resource_deposit_count: int = 54
@export var spawn_clearance: float = 2.2

var _primary_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _noise_configured: bool = false
var _generated: bool = false


func _ready() -> void:
    ensure_generated()


func ensure_generated() -> void:
    if _generated:
        return
    _ensure_noise_configured()
    _build_terrain()
    _scatter_resource_deposits()
    _generated = true
    print("[TERRAIN] generated before vehicle placement; seed=%d size=%.0fm" % [terrain_seed, terrain_size])


func is_generated() -> bool:
    return _generated


func get_height_at(x: float, z: float) -> float:
    _ensure_noise_configured()
    var broad := _primary_noise.get_noise_2d(x, z) * height_scale
    var detail := _detail_noise.get_noise_2d(x, z) * height_scale * 0.22
    var distance_from_spawn := Vector2(x, z).length()
    var spawn_blend := smoothstep(10.0, 26.0, distance_from_spawn)
    return (broad + detail) * spawn_blend


func get_safe_spawn_position(local_xz: Vector2 = Vector2.ZERO) -> Vector3:
    ensure_generated()
    var local_position := Vector3(
        local_xz.x,
        get_height_at(local_xz.x, local_xz.y) + spawn_clearance,
        local_xz.y
    )
    return to_global(local_position)


func _ensure_noise_configured() -> void:
    if _noise_configured:
        return
    _configure_noise()
    _noise_configured = true


func _configure_noise() -> void:
    _primary_noise.seed = terrain_seed
    _primary_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _primary_noise.frequency = noise_frequency
    _primary_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    _primary_noise.fractal_octaves = 4
    _primary_noise.fractal_gain = 0.48
    _primary_noise.fractal_lacunarity = 2.0

    _detail_noise.seed = terrain_seed + 137
    _detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
    _detail_noise.frequency = detail_frequency
    _detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    _detail_noise.fractal_octaves = 3
    _detail_noise.fractal_gain = 0.42

    _rng.seed = terrain_seed


func _build_terrain() -> void:
    var vertex_count_per_side := resolution + 1
    var step := terrain_size / float(resolution)
    var half_size := terrain_size * 0.5

    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    vertices.resize(vertex_count_per_side * vertex_count_per_side)
    normals.resize(vertex_count_per_side * vertex_count_per_side)
    colors.resize(vertex_count_per_side * vertex_count_per_side)
    uvs.resize(vertex_count_per_side * vertex_count_per_side)

    for z_index: int in range(vertex_count_per_side):
        for x_index: int in range(vertex_count_per_side):
            var index := z_index * vertex_count_per_side + x_index
            var x := -half_size + float(x_index) * step
            var z := -half_size + float(z_index) * step
            var y := get_height_at(x, z)
            vertices[index] = Vector3(x, y, z)
            uvs[index] = Vector2(float(x_index) / float(resolution), float(z_index) / float(resolution)) * 12.0

            var left := get_height_at(x - step, z)
            var right := get_height_at(x + step, z)
            var back := get_height_at(x, z - step)
            var front := get_height_at(x, z + step)
            normals[index] = Vector3(left - right, step * 2.0, back - front).normalized()

            var material_noise := _detail_noise.get_noise_2d(x + 411.0, z - 193.0)
            var base_color := Color(0.20, 0.18, 0.15, 1.0)
            if material_noise > 0.24:
                base_color = Color(0.28, 0.24, 0.17, 1.0)
            elif material_noise < -0.28:
                base_color = Color(0.10, 0.12, 0.13, 1.0)
            elif y > height_scale * 0.52:
                base_color = Color(0.32, 0.30, 0.26, 1.0)
            colors[index] = base_color

    for z_index: int in range(resolution):
        for x_index: int in range(resolution):
            var top_left := z_index * vertex_count_per_side + x_index
            var top_right := top_left + 1
            var bottom_left := (z_index + 1) * vertex_count_per_side + x_index
            var bottom_right := bottom_left + 1

            indices.append(top_left)
            indices.append(bottom_left)
            indices.append(top_right)
            indices.append(top_right)
            indices.append(bottom_left)
            indices.append(bottom_right)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.96
    material.metallic = 0.02
    mesh.surface_set_material(0, material)

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "TerrainMesh"
    mesh_instance.mesh = mesh
    add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    collision.name = "TerrainCollision"
    collision.shape = mesh.create_trimesh_shape()
    add_child(collision)


func _scatter_resource_deposits() -> void:
    var deposits := Node3D.new()
    deposits.name = "ResourceDeposits"
    add_child(deposits)

    for index: int in range(resource_deposit_count):
        var x := _rng.randf_range(-terrain_size * 0.46, terrain_size * 0.46)
        var z := _rng.randf_range(-terrain_size * 0.46, terrain_size * 0.46)
        if Vector2(x, z).length() < 15.0:
            continue

        var deposit := MeshInstance3D.new()
        deposit.name = "Deposit_%02d" % index
        var height := _rng.randf_range(0.55, 2.4)
        var radius := _rng.randf_range(0.38, 1.2)
        var mesh := CylinderMesh.new()
        mesh.top_radius = radius * _rng.randf_range(0.35, 0.72)
        mesh.bottom_radius = radius
        mesh.height = height
        mesh.radial_segments = _rng.randi_range(5, 9)
        deposit.mesh = mesh
        deposit.position = Vector3(x, get_height_at(x, z) + height * 0.46, z)
        deposit.rotation_degrees = Vector3(
            _rng.randf_range(-9.0, 9.0),
            _rng.randf_range(0.0, 360.0),
            _rng.randf_range(-9.0, 9.0)
        )

        var material := StandardMaterial3D.new()
        match index % 4:
            0:
                material.albedo_color = Color(0.09, 0.10, 0.11, 1.0)
                material.metallic = 0.10
                material.roughness = 0.95
            1:
                material.albedo_color = Color(0.30, 0.13, 0.08, 1.0)
                material.metallic = 0.58
                material.roughness = 0.42
            2:
                material.albedo_color = Color(0.18, 0.26, 0.22, 1.0)
                material.metallic = 0.36
                material.roughness = 0.48
            _:
                material.albedo_color = Color(0.34, 0.31, 0.23, 1.0)
                material.metallic = 0.02
                material.roughness = 0.86
        deposit.material_override = material
        deposits.add_child(deposit)
