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
        material: Material
) -> ArrayMesh:
    var safe_resolution := maxi(resolution, 8)
    var padded_radius := radius * (1.0 + surface_noise + 0.04)
    var cell_size := maxf(
        requested_cell_size,
        (padded_radius * 2.0) / float(safe_resolution)
    )
    var half_extent := cell_size * float(safe_resolution) * 0.5

    var noise := FastNoiseLite.new()
    noise.seed = seed
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 1.65 / maxf(radius, 1.0)
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.48
    noise.fractal_lacunarity = 2.0

    var occupied := PackedByteArray()
    occupied.resize(safe_resolution * safe_resolution * safe_resolution)

    for z: int in range(safe_resolution):
        for y: int in range(safe_resolution):
            for x: int in range(safe_resolution):
                var center := _cell_center(x, y, z, cell_size, half_extent)
                var sample := noise.get_noise_3d(center.x, center.y, center.z)
                var local_radius := radius * (1.0 + sample * surface_noise)
                if center.length() <= local_radius:
                    occupied[_index(x, y, z, safe_resolution)] = 1

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
                var color_noise := noise.get_noise_3d(
                    center.x + 91.0,
                    center.y - 37.0,
                    center.z + 211.0
                )
                var brightness := 0.82 + (color_noise + 1.0) * 0.11
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
        "[VOXEL_ASTEROID] radius=%.1f resolution=%d cell=%.2f exposed_faces=%d vertices=%d" % [
            radius,
            safe_resolution,
            cell_size,
            face_count,
            vertices.size(),
        ]
    )
    return mesh


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
