class_name SpaceWorld
extends Node3D

const ROCK_DIFFUSE: Texture2D = preload("res://assets/materials/polyhaven/rock_surface/rock_surface_diff_1k.jpg")
const ROCK_NORMAL: Texture2D = preload("res://assets/materials/polyhaven/rock_surface/rock_surface_nor_gl_1k.jpg")
const ROCK_ROUGHNESS: Texture2D = preload("res://assets/materials/polyhaven/rock_surface/rock_surface_rough_1k.jpg")
const PRIMARY_STAR_DIRECTION := Vector3(-0.56, 0.34, -0.76).normalized()
const PRIMARY_STAR_DISTANCE: float = 1450.0

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

    _configure_primary_star()
    _build_visible_sun()
    _build_starter_asteroid()
    _generate_asteroid_records()
    _build_far_asteroid_physics()
    _build_far_asteroid_sectors()
    _build_star_field()
    _generated = true

    print(
        "[SPACE_WORLD] generated seed=%d asteroids=%d sectors=%d radius=%.0fm local_gravity=%.1fm/s2" % [
            settings.world_seed,
            settings.asteroid_count,
            _sector_nodes.size(),
            settings.field_radius,
            settings.asteroid_surface_gravity,
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


func get_gravity_context(world_position: Vector3) -> Dictionary:
    var best: Dictionary = {}
    var best_strength := 0.0

    best = _consider_gravity_source(
        world_position,
        _starter_asteroid_center,
        _starter_asteroid_radius,
        best,
        best_strength
    )
    if not best.is_empty():
        best_strength = float(best.get("gravity_strength", 0.0))

    for record: Dictionary in _asteroid_records:
        var candidate := _consider_gravity_source(
            world_position,
            record["center"],
            float(record["surface_radius"]),
            best,
            best_strength
        )
        if not candidate.is_empty() and candidate != best:
            best = candidate
            best_strength = float(best.get("gravity_strength", 0.0))

    if best.is_empty():
        return {
            "active": false,
            "gravity_strength": 0.0,
            "up": Vector3.ZERO,
            "surface_altitude": INF,
        }
    return best


func build_environment() -> Environment:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.003, 0.005, 0.012, 1.0)
    environment.background_energy_multiplier = 0.42
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.20, 0.24, 0.34, 1.0)
    environment.ambient_light_energy = 0.34
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.ssao_enabled = true
    environment.ssao_radius = 4.0
    environment.ssao_intensity = 2.1
    environment.ssil_enabled = true
    environment.ssil_intensity = 0.72
    environment.volumetric_fog_enabled = false
    return environment


func _configure_primary_star() -> void:
    var star_light := get_parent().get_node_or_null("StarLight") as DirectionalLight3D
    if star_light == null:
        star_light = DirectionalLight3D.new()
        star_light.name = "StarLight"
        get_parent().add_child(star_light)

    star_light.light_color = Color(1.0, 0.91, 0.77, 1.0)
    star_light.light_energy = 1.9
    star_light.shadow_enabled = true
    star_light.look_at(
        star_light.global_position - PRIMARY_STAR_DIRECTION,
        Vector3.UP
    )


func _build_visible_sun() -> void:
    var sun_mesh := SphereMesh.new()
    sun_mesh.radius = 28.0
    sun_mesh.height = 56.0
    sun_mesh.radial_segments = 24
    sun_mesh.rings = 12

    var sun_material := StandardMaterial3D.new()
    sun_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sun_material.albedo_color = Color(1.0, 0.76, 0.34, 1.0)
    sun_material.emission_enabled = true
    sun_material.emission = Color(1.0, 0.63, 0.20, 1.0)
    sun_material.emission_energy_multiplier = 12.0
    sun_mesh.material = sun_material

    var sun := MeshInstance3D.new()
    sun.name = "PrimaryStarVisual"
    sun.mesh = sun_mesh
    sun.position = PRIMARY_STAR_DIRECTION * PRIMARY_STAR_DISTANCE
    sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    sun.visibility_range_end = settings.far_visibility_distance * 1.5
    add_child(sun)


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
        _rock_material,
        settings.voxel_caves_enabled,
        settings.voxel_cave_noise_frequency,
        settings.voxel_cave_threshold,
        settings.voxel_cave_shell_thickness,
        settings.voxel_cave_tunnel_radius,
        settings.voxel_cave_chamber_radius
    )

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "VoxelRockMesh"
    mesh_instance.mesh = mesh
    mesh_instance.visibility_range_end = settings.detailed_distance * 1.8
    mesh_instance.extra_cull_margin = 0.0
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    collision.name = "SurfaceAndCavernCollision"
    collision.shape = mesh.create_trimesh_shape()
    body.add_child(collision)

    if not settings.voxel_caves_enabled:
        var occluder_instance := OccluderInstance3D.new()
        occluder_instance.name = "SimpleSphereOccluder"
        var occluder := SphereOccluder3D.new()
        occluder.radius = _starter_asteroid_radius * 0.86
        occluder_instance.occluder = occluder
        body.add_child(occluder_instance)
    else:
        _add_cave_entrance_beacons(body)

    _add_gravity_zone(body, _starter_asteroid_radius)


func _add_cave_entrance_beacons(parent: Node3D) -> void:
    var entrances := VoxelAsteroidMesher.get_cavern_entrances(_starter_asteroid_radius)
    var colors: Array[Color] = [
        Color(1.0, 0.54, 0.14, 1.0),
        Color(0.18, 0.72, 1.0, 1.0),
    ]

    for index: int in range(entrances.size()):
        var beacon_mesh := SphereMesh.new()
        beacon_mesh.radius = 0.8
        beacon_mesh.height = 1.6

        var beacon_material := StandardMaterial3D.new()
        beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        beacon_material.albedo_color = colors[index % colors.size()]
        beacon_material.emission_enabled = true
        beacon_material.emission = colors[index % colors.size()]
        beacon_material.emission_energy_multiplier = 5.0
        beacon_mesh.material = beacon_material

        var beacon := MeshInstance3D.new()
        beacon.name = "CaveEntranceBeacon_%d" % index
        beacon.mesh = beacon_mesh
        beacon.position = entrances[index]
        beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(beacon)

        var light := OmniLight3D.new()
        light.name = "CaveEntranceLight_%d" % index
        light.position = entrances[index]
        light.light_color = colors[index % colors.size()]
        light.light_energy = 3.0
        light.omni_range = 12.0
        light.shadow_enabled = false
        parent.add_child(light)


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
        var surface_radius := radius * minf(stretch.x, minf(stretch.y, stretch.z)) * 0.90

        _asteroid_records.append({
            "center": position,
            "radius": radius,
            "surface_radius": surface_radius,
            "stretch": stretch,
            "rotation": rotation,
            "sector": sector,
        })


func _build_far_asteroid_physics() -> void:
    var physics_root := Node3D.new()
    physics_root.name = "AsteroidPhysicsProxies"
    add_child(physics_root)

    for index: int in range(_asteroid_records.size()):
        var record: Dictionary = _asteroid_records[index]
        var surface_radius := float(record["surface_radius"])

        var body := StaticBody3D.new()
        body.name = "AsteroidProxy_%03d" % index
        body.position = record["center"]
        physics_root.add_child(body)

        var collision := CollisionShape3D.new()
        var surface_shape := SphereShape3D.new()
        surface_shape.radius = surface_radius
        collision.shape = surface_shape
        body.add_child(collision)

        _add_gravity_zone(body, surface_radius)


func _add_gravity_zone(parent: Node3D, surface_radius: float) -> void:
    var area := Area3D.new()
    area.name = "GravityField"
    area.gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
    area.gravity_point = true
    area.gravity_point_center = Vector3.ZERO
    area.gravity = settings.asteroid_surface_gravity
    area.gravity_point_unit_distance = surface_radius
    area.monitorable = false
    parent.add_child(area)

    var collision := CollisionShape3D.new()
    collision.name = "GravityInfluence"
    var influence_shape := SphereShape3D.new()
    influence_shape.radius = surface_radius * settings.gravity_influence_multiplier
    collision.shape = influence_shape
    area.add_child(collision)


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


func _consider_gravity_source(
        world_position: Vector3,
        center: Vector3,
        surface_radius: float,
        current_best: Dictionary,
        current_strength: float
) -> Dictionary:
    var delta := world_position - center
    var distance := delta.length()
    var influence_radius := surface_radius * settings.gravity_influence_multiplier
    if distance > influence_radius or distance < 0.001:
        return current_best

    var gravity_strength := settings.asteroid_surface_gravity * pow(
        surface_radius / maxf(distance, surface_radius * 0.15),
        2.0
    )
    if gravity_strength <= current_strength:
        return current_best

    return {
        "active": true,
        "center": center,
        "surface_radius": surface_radius,
        "surface_altitude": distance - surface_radius,
        "up": delta.normalized(),
        "gravity_strength": gravity_strength,
        "influence_radius": influence_radius,
    }


func _create_rock_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.72, 0.69, 0.65, 1.0)
    material.albedo_texture = ROCK_DIFFUSE
    material.vertex_color_use_as_albedo = true
    material.normal_enabled = true
    material.normal_texture = ROCK_NORMAL
    material.roughness = 1.0
    material.roughness_texture = ROCK_ROUGHNESS
    material.metallic = 0.08
    return material
