class_name SpaceWorld
extends Node3D

@export var settings: WorldSettings

var _generated: bool = false
var _rng := RandomNumberGenerator.new()
var _starter_asteroid_center := Vector3.ZERO
var _starter_asteroid_radius: float = 42.0
var _rock_material: StandardMaterial3D
var _asteroid_records: Array[Dictionary] = []
var _sector_nodes: Dictionary = {}


func ensure_generated() -> void:
    if _generated:
        return
    if settings == null:
        push_error("SpaceWorld requires a WorldSettings resource.")
        return

    get_tree().root.use_occlusion_culling = true
    _rng.seed = settings.world_seed
    _starter_asteroid_radius = settings.starter_asteroid_radius
    _rock_material = _create_rock_material()

    _build_starter_asteroid()
    _generate_asteroid_records()
    _build_far_asteroid_sectors()
    _build_star_field()
    _generated = true

    print(
        "[SPACE_WORLD] generated seed=%d asteroids=%d sectors=%d radius=%.0fm" % [
            settings.world_seed,
            settings.asteroid_count,
            _sector_nodes.size(),
            settings.field_radius,
        ]
    )


func is_generated() -> bool:
    return _generated


func get_safe_spawn_transform() -> Transform3D:
    ensure_generated()
    var spawn_position := _starter_asteroid_center + Vector3.UP * (
        _starter_asteroid_radius + settings.spawn_clearance
    )
    return Transform3D(Basis.IDENTITY, spawn_position)


func get_starter_asteroid_center() -> Vector3:
    return _starter_asteroid_center


func get_starter_asteroid_radius() -> float:
    return _starter_asteroid_radius


func get_asteroid_records() -> Array[Dictionary]:
    var copy: Array[Dictionary] = []
    for record: Dictionary in _asteroid_records:
        copy.append(record.duplicate(true))
    return copy


func build_environment() -> Environment:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.0015, 0.0025, 0.0075, 1.0)
    environment.background_energy_multiplier = 0.32
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.16, 0.20, 0.30, 1.0)
    environment.ambient_light_energy = 0.18
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.ssao_enabled = true
    environment.ssao_radius = 4.0
    environment.ssao_intensity = 2.6
    environment.ssil_enabled = true
    environment.ssil_intensity = 0.55
    environment.volumetric_fog_enabled = false
    return environment


func _build_starter_asteroid() -> void:
    var body := StaticBody3D.new()
    body.name = "StarterAsteroid"
    body.position = _starter_asteroid_center
    add_child(body)

    var mesh := VoxelAsteroidMesher.build_mesh(
        _starter_asteroid_radius,
        settings.voxel_resolution,
        settings.voxel_cell_size,
        settings.world_seed + 9001,
        settings.voxel_surface_noise,
        _rock_material
    )

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "VoxelRockMesh"
    mesh_instance.mesh = mesh
    mesh_instance.visibility_range_end = settings.detailed_distance * 1.8
    mesh_instance.extra_cull_margin = 0.0
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    collision.name = "SurfaceCollision"
    collision.shape = mesh.create_trimesh_shape()
    body.add_child(collision)

    var occluder_instance := OccluderInstance3D.new()
    occluder_instance.name = "SimpleSphereOccluder"
    var occluder := SphereOccluder3D.new()
    occluder.radius = _starter_asteroid_radius * 0.86
    occluder_instance.occluder = occluder
    body.add_child(occluder_instance)


func _generate_asteroid_records() -> void:
    _asteroid_records.clear()
    var attempts := 0
    var exclusion_radius := _starter_asteroid_radius * 3.4

    while _asteroid_records.size() < settings.asteroid_count and attempts < settings.asteroid_count * 30:
        attempts += 1
        var position := Vector3(
            _rng.randf_range(-settings.field_radius, settings.field_radius),
            _rng.randf_range(-settings.field_radius * 0.72, settings.field_radius * 0.72),
            _rng.randf_range(-settings.field_radius, settings.field_radius)
        )
        if position.length() < exclusion_radius:
            continue

        var radius := _rng.randf_range(settings.asteroid_min_radius, settings.asteroid_max_radius)
        var stretch := Vector3(
            _rng.randf_range(0.72, 1.38),
            _rng.randf_range(0.70, 1.24),
            _rng.randf_range(0.72, 1.38)
        )
        var rotation := Vector3(
            _rng.randf_range(0.0, TAU),
            _rng.randf_range(0.0, TAU),
            _rng.randf_range(0.0, TAU)
        )
        var sector := Vector3i(
            floori(position.x / settings.sector_size),
            floori(position.y / settings.sector_size),
            floori(position.z / settings.sector_size)
        )

        _asteroid_records.append({
            "center": position,
            "radius": radius,
            "stretch": stretch,
            "rotation": rotation,
            "sector": sector,
        })


func _build_far_asteroid_sectors() -> void:
    var grouped: Dictionary = {}
    for record: Dictionary in _asteroid_records:
        var sector: Vector3i = record["sector"]
        if not grouped.has(sector):
            grouped[sector] = []
        var sector_records: Array = grouped[sector]
        sector_records.append(record)

    var base_mesh := SphereMesh.new()
    base_mesh.radius = 1.0
    base_mesh.height = 2.0
    base_mesh.radial_segments = 8
    base_mesh.rings = 5
    base_mesh.material = _rock_material

    for sector_key: Variant in grouped.keys():
        var sector: Vector3i = sector_key
        var records: Array = grouped[sector]
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = base_mesh
        multimesh.instance_count = records.size()

        for index: int in range(records.size()):
            var record: Dictionary = records[index]
            var radius: float = record["radius"]
            var stretch: Vector3 = record["stretch"]
            var rotation: Vector3 = record["rotation"]
            var center: Vector3 = record["center"]
            var basis := Basis.from_euler(rotation).scaled(stretch * radius)
            multimesh.set_instance_transform(index, Transform3D(basis, center))

        var field := MultiMeshInstance3D.new()
        field.name = "AsteroidSector_%d_%d_%d" % [sector.x, sector.y, sector.z]
        field.multimesh = multimesh
        field.visibility_range_end = settings.far_visibility_distance
        field.extra_cull_margin = 0.0
        field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        add_child(field)
        _sector_nodes[sector] = field


func _build_star_field() -> void:
    var star_mesh := BoxMesh.new()
    star_mesh.size = Vector3.ONE * 0.8

    var star_material := StandardMaterial3D.new()
    star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    star_material.albedo_color = Color(0.78, 0.86, 1.0, 1.0)
    star_material.emission_enabled = true
    star_material.emission = Color(0.65, 0.76, 1.0, 1.0)
    star_material.emission_energy_multiplier = 3.2
    star_mesh.material = star_material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = star_mesh
    multimesh.instance_count = settings.star_count

    for index: int in range(settings.star_count):
        var direction := Vector3(
            _rng.randf_range(-1.0, 1.0),
            _rng.randf_range(-1.0, 1.0),
            _rng.randf_range(-1.0, 1.0)
        )
        if direction.length_squared() < 0.001:
            direction = Vector3.FORWARD
        direction = direction.normalized()
        var distance := _rng.randf_range(settings.star_inner_radius, settings.star_outer_radius)
        var size := _rng.randf_range(0.55, 2.0)
        var basis := Basis.IDENTITY.scaled(Vector3.ONE * size)
        multimesh.set_instance_transform(index, Transform3D(basis, direction * distance))

    var stars := MultiMeshInstance3D.new()
    stars.name = "StarField"
    stars.multimesh = multimesh
    stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(stars)


func _create_rock_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.metallic = 0.12
    material.roughness = 0.88
    return material
