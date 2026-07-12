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

static func generate_heuristic(size: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    var visited: Dictionary = {}
    _dfs(Vector2i(0, 0), path, visited, size)
    return path

static func _dfs(coord: Vector2i, path: Array[Vector2i], visited: Dictionary, size: Vector2i) -> bool:
    path.append(coord)
    visited[coord] = true
    if path.size() == size.x * size.y:
        return true
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
    for d in dirs:
        var nb: Vector2i = coord + d
        if nb.x >= 0 and nb.x < size.x and nb.y >= 0 and nb.y < size.y and not visited.has(nb):
            if _dfs(nb, path, visited, size):
                return true
    path.pop_back()
    visited.erase(coord)
    return false

static func generate_random_walk(size: Vector2i, start: Vector2i, end: Vector2i) -> Array[Vector2i]:
    if end.x >= 0:
        var reach_path: Array[Vector2i] = []
        var visited: Dictionary = {}
        _dfs_to_end(start, end, reach_path, visited, size)
        return reach_path
    var path: Array[Vector2i] = [start]
    var visited2: Dictionary = {start: true}
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    while true:
        var cur: Vector2i = path[path.size() - 1]
        var candidates: Array[Vector2i] = []
        for d in dirs:
            var nb: Vector2i = cur + d
            if nb.x >= 0 and nb.x < size.x and nb.y >= 0 and nb.y < size.y and not visited2.has(nb):
                candidates.append(nb)
        if candidates.is_empty():
            break
        candidates.shuffle()
        var nxt: Vector2i = candidates[0]
        path.append(nxt)
        visited2[nxt] = true
    return path

static func _dfs_to_end(coord: Vector2i, end: Vector2i, path: Array[Vector2i], visited: Dictionary, size: Vector2i) -> bool:
    path.append(coord)
    visited[coord] = true
    if coord == end:
        return true
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    dirs.shuffle()
    for d in dirs:
        var nb: Vector2i = coord + d
        if nb.x >= 0 and nb.x < size.x and nb.y >= 0 and nb.y < size.y and not visited.has(nb):
            if _dfs_to_end(nb, end, path, visited, size):
                return true
    path.pop_back()
    visited.erase(coord)
    return false
