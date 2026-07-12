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

static func generate_hilbert(size: Vector2i) -> Array[Vector2i]:
    if not _is_square_power_of_2(size):
        return generate_spiral(size)
    var n: int = size.x
    var path: Array[Vector2i] = []
    for d in range(n * n):
        path.append(_d2xy(n, d))
    return path

static func _is_square_power_of_2(size: Vector2i) -> bool:
    if size.x != size.y:
        return false
    var n: int = size.x
    return n > 0 and (n & (n - 1)) == 0

static func _d2xy(n: int, d: int) -> Vector2i:
    var x: int = 0
    var y: int = 0
    var t: int = d
    var s: int = 1
    while s < n:
        var rx: int = 1 & (t >> 1)
        var ry: int = 1 & (t ^ rx)
        if ry == 0:
            if rx == 1:
                x = s - 1 - x
                y = s - 1 - y
            var tmp: int = x
            x = y
            y = tmp
        x += s * rx
        y += s * ry
        t = t >> 2
        s *= 2
    return Vector2i(x, y)
