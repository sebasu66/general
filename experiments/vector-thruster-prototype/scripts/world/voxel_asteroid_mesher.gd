class_name VoxelAsteroidMesher
extends RefCounted

const DIRECTIONS: Array[Vector3i] = [
    Vector3i(1, 0, 0),
    Vector3i(-1, 0, 0),
    Vector3i(0, 1, 0),
    Vector3i(0, -1, 0),
    Vector3i(0, 0, 1),
    Vector3i(0, 0, -1),
]

const NORMALS: Array[Vector3] = [
    Vector3.RIGHT,
    Vector3.LEFT,
    Vector3.UP,
    Vector3.DOWN,
    Vector3.BACK,
    Vector3.FORWARD,
]

const FACE_U: Array[Vector3] = [
    Vector3.UP,
    Vector3.UP,
    Vector3.BACK,
    Vector3.BACK,
    Vector3.RIGHT,
    Vector3.RIGHT,
]

const FACE_V: Array[Vector3] = [
    Vector3.BACK,
    Vector3.FORWARD,
    Vector3.RIGHT,
    Vector3.LEFT,
    Vector3.UP,
    Vector3.DOWN,
]


static func build_mesh(
        radius: float,
        resolution: int,
        requested_cell_size: float,
        seed: int,
        surface_noise: float,
        material: Material,
        caves_enabled: bool = false,
        cave_noise_frequency: float = 0.085,
        cave_threshold: float = 0.50,
        cave_shell_thickness: float = 5.0,
        cave_tunnel_radius: float = 5.5,
        cave_chamber_radius: float = 10.0
) -> ArrayMesh:
    var safe_resolution := maxi(resolution, 8)
    var padded_radius := radius * (1.0 + surface_noise + 0.04)
    var cell_size := maxf(
        requested_cell_size,
        (padded_radius * 2.0) / float(safe_resolution)
    )
    var half_extent := cell_size * float(safe_resolution) * 0.5

    var surface_field := FastNoiseLite.new()
    surface_field.seed = seed
    surface_field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    surface_field.frequency = 1.65 / maxf(radius, 1.0)
    surface_field.fractal_type = FastNoiseLite.FRACTAL_FBM
    surface_field.fractal_octaves = 4
    surface_field.fractal_gain = 0.48
    surface_field.fractal_lacunarity = 2.0

    var cave_field := FastNoiseLite.new()
    cave_field.seed = seed + 17041
    cave_field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    cave_field.frequency = cave_noise_frequency
    cave_field.fractal_type = FastNoiseLite.FRACTAL_FBM
    cave_field.fractal_octaves = 3
    cave_field.fractal_gain = 0.52
    cave_field.fractal_lacunarity = 2.1

    var cave_gate := FastNoiseLite.new()
    cave_gate.seed = seed + 39019
    cave_gate.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    cave_gate.frequency = cave_noise_frequency * 0.48
    cave_gate.fractal_type = FastNoiseLite.FRACTAL_FBM
    cave_gate.fractal_octaves = 2
    cave_gate.fractal_gain = 0.5

    var cavern_layout := _build_cavern_layout(
        radius,
        cave_tunnel_radius,
        cave_chamber_radius
    )

    var occupied := PackedByteArray()
    occupied.resize(safe_resolution * safe_resolution * safe_resolution)
    var solid_voxel_count := 0
    var carved_voxel_count := 0

    for z: int in range(safe_resolution):
        for y: int in range(safe_resolution):
            for x: int in range(safe_resolution):
                var center := _cell_center(x, y, z, cell_size, half_extent)
                var sample := surface_field.get_noise_3d(center.x, center.y, center.z)
                var local_radius := radius * (1.0 + sample * surface_noise)
                if center.length() > local_radius:
                    continue

                if caves_enabled and _should_carve_cave(
                    center,
                    local_radius,
                    cave_shell_thickness,
                    cave_threshold,
                    cave_field,
                    cave_gate,
                    cavern_layout
                ):
                    carved_voxel_count += 1
                    continue

                occupied[_index(x, y, z, safe_resolution)] = 1
                solid_voxel_count += 1

    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var face_count := 0

    for z: int in range(safe_resolution):
        for y: int in range(safe_resolution):
            for x: int in range(safe_resolution):
                if occupied[_index(x, y, z, safe_resolution)] == 0:
                    continue

                var center := _cell_center(x, y, z, cell_size, half_extent)
                var color_noise := surface_field.get_noise_3d(
                    center.x + 91.0,
                    center.y - 37.0,
                    center.z + 211.0
                )
                var brightness := 0.82 + (color_noise + 1.0) * 0.11
                if caves_enabled and center.length() < radius * 0.82:
                    brightness *= 0.86
                var face_color := Color(0.22, 0.205, 0.19, 1.0) * brightness
                face_color.a = 1.0

                for face_index: int in range(DIRECTIONS.size()):
                    var neighbor := Vector3i(x, y, z) + DIRECTIONS[face_index]
                    if _is_occupied(neighbor, occupied, safe_resolution):
                        continue
                    _append_face(
                        vertices,
                        normals,
                        colors,
                        uvs,
                        indices,
                        center,
                        cell_size,
                        face_index,
                        face_color
                    )
                    face_count += 1

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    if not vertices.is_empty():
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        mesh.surface_set_material(0, material)

    print(
        "[VOXEL_ASTEROID] radius=%.1f resolution=%d cell=%.2f solid=%d carved=%d exposed_faces=%d vertices=%d caves=%s" % [
            radius,
            safe_resolution,
            cell_size,
            solid_voxel_count,
            carved_voxel_count,
            face_count,
            vertices.size(),
            str(caves_enabled),
        ]
    )
    return mesh


static func get_cavern_entrances(radius: float) -> Array[Vector3]:
    var layout := _build_cavern_layout(radius, 1.0, 1.0)
    var entrances: Array[Vector3] = []
    for entrance: Vector3 in layout["entrances"]:
        entrances.append(entrance)
    return entrances


static func _build_cavern_layout(
        radius: float,
        tunnel_radius: float,
        chamber_radius: float
) -> Dictionary:
    # A deterministic Deep-Rock-like test layout: two surface entrances feed a
    # central cavern, with three irregular branch chambers. Noise carving below
    # extends this skeleton with smaller pockets while these explicit capsules
    # guarantee that the important spaces are connected and reachable.
    var central := Vector3(radius * 0.04, -radius * 0.06, radius * 0.02)
    var upper := Vector3(-radius * 0.28, radius * 0.18, radius * 0.22)
    var lower := Vector3(radius * 0.28, -radius * 0.22, -radius * 0.28)
    var side := Vector3(-radius * 0.26, -radius * 0.10, radius * 0.32)

    var entrance_a := Vector3(radius * 1.12, -radius * 0.05, radius * 0.12)
    var entrance_b := Vector3(-radius * 0.08, radius * 0.06, -radius * 1.12)

    var chambers: Array[Dictionary] = [
        {"center": central, "radius": chamber_radius * 1.15},
        {"center": upper, "radius": chamber_radius},
        {"center": lower, "radius": chamber_radius * 0.95},
        {"center": side, "radius": chamber_radius * 0.85},
    ]

    var tunnels: Array[Dictionary] = [
        {"from": entrance_a, "to": central, "radius": tunnel_radius * 1.15},
        {"from": central, "to": upper, "radius": tunnel_radius},
        {"from": central, "to": lower, "radius": tunnel_radius},
        {"from": central, "to": side, "radius": tunnel_radius * 0.90},
        {"from": entrance_b, "to": lower, "radius": tunnel_radius},
    ]

    return {
        "entrances": [entrance_a, entrance_b],
        "chambers": chambers,
        "tunnels": tunnels,
    }


static func _should_carve_cave(
        center: Vector3,
        local_radius: float,
        shell_thickness: float,
        cave_threshold: float,
        cave_field: FastNoiseLite,
        cave_gate: FastNoiseLite,
        cavern_layout: Dictionary
) -> bool:
    var roughness_noise := cave_field.get_noise_3d(
        center.x * 1.65 + 17.0,
        center.y * 1.65 - 31.0,
        center.z * 1.65 + 53.0
    )
    var roughness := 1.0 + roughness_noise * 0.16

    var chambers: Array = cavern_layout["chambers"]
    for chamber: Dictionary in chambers:
        var chamber_center: Vector3 = chamber["center"]
        var chamber_radius: float = float(chamber["radius"]) * roughness
        if center.distance_to(chamber_center) <= chamber_radius:
            return true

    var tunnels: Array = cavern_layout["tunnels"]
    for tunnel: Dictionary in tunnels:
        var tunnel_from: Vector3 = tunnel["from"]
        var tunnel_to: Vector3 = tunnel["to"]
        var tunnel_radius: float = float(tunnel["radius"]) * roughness
        if _distance_to_segment(center, tunnel_from, tunnel_to) <= tunnel_radius:
            return true

    # Preserve a mostly-solid outer shell except where the explicit entrance
    # tunnels pierce it. Interior noise creates pockets and side passages with
    # organic walls rather than reducing the asteroid to a hollow sphere.
    var surface_depth := local_radius - center.length()
    if surface_depth <= shell_thickness:
        return false

    var cave_value := cave_field.get_noise_3d(center.x, center.y, center.z)
    var gate_value := cave_gate.get_noise_3d(center.x, center.y, center.z)
    return cave_value > cave_threshold and gate_value > -0.22


static func _distance_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
    var segment := segment_end - segment_start
    var length_squared := segment.length_squared()
    if length_squared <= 0.000001:
        return point.distance_to(segment_start)
    var t := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
    return point.distance_to(segment_start + segment * t)


static func _append_face(
        vertices: PackedVector3Array,
        normals: PackedVector3Array,
        colors: PackedColorArray,
        uvs: PackedVector2Array,
        indices: PackedInt32Array,
        center: Vector3,
        cell_size: float,
        face_index: int,
        face_color: Color
) -> void:
    var normal := NORMALS[face_index]
    var tangent_u := FACE_U[face_index]
    var tangent_v := FACE_V[face_index]
    var half := cell_size * 0.5
    var face_center := center + normal * half
    var base_index := vertices.size()

    vertices.append(face_center + (-tangent_u - tangent_v) * half)
    vertices.append(face_center + (tangent_u - tangent_v) * half)
    vertices.append(face_center + (tangent_u + tangent_v) * half)
    vertices.append(face_center + (-tangent_u + tangent_v) * half)

    for _corner: int in range(4):
        normals.append(normal)
        colors.append(face_color)

    uvs.append(Vector2(0.0, 1.0))
    uvs.append(Vector2(1.0, 1.0))
    uvs.append(Vector2(1.0, 0.0))
    uvs.append(Vector2(0.0, 0.0))

    # Godot considers clockwise triangles front-facing. FACE_U x FACE_V points
    # outward, so the original 0-1-2 order was counter-clockwise from outside
    # and caused the asteroid shell to render inside-out with back-face culling.
    indices.append(base_index)
    indices.append(base_index + 2)
    indices.append(base_index + 1)
    indices.append(base_index)
    indices.append(base_index + 3)
    indices.append(base_index + 2)


static func _cell_center(
        x: int,
        y: int,
        z: int,
        cell_size: float,
        half_extent: float
) -> Vector3:
    return Vector3(
        (float(x) + 0.5) * cell_size - half_extent,
        (float(y) + 0.5) * cell_size - half_extent,
        (float(z) + 0.5) * cell_size - half_extent
    )


static func _index(x: int, y: int, z: int, resolution: int) -> int:
    return x + y * resolution + z * resolution * resolution


static func _is_occupied(
        coord: Vector3i,
        occupied: PackedByteArray,
        resolution: int
) -> bool:
    if (
        coord.x < 0 or coord.y < 0 or coord.z < 0
        or coord.x >= resolution or coord.y >= resolution or coord.z >= resolution
    ):
        return false
    return occupied[_index(coord.x, coord.y, coord.z, resolution)] != 0
