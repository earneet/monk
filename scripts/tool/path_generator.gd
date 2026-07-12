class_name PathGenerator

static func generate_spiral(size: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    if size.x <= 0 or size.y <= 0:
        return path
    var visited: Dictionary = {}
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
    var coord: Vector2i = Vector2i(0, 0)
    var dir_idx: int = 0
    var total: int = size.x * size.y
    while path.size() < total:
        path.append(coord)
        visited[coord] = true
        if path.size() >= total:
            break
        var next: Vector2i = coord + dirs[dir_idx]
        if next.x < 0 or next.x >= size.x or next.y < 0 or next.y >= size.y or visited.has(next):
            dir_idx = (dir_idx + 1) % 4
            next = coord + dirs[dir_idx]
        coord = next
    return path
