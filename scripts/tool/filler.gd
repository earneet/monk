class_name Filler

static func fill(wlr: WorkLevelResource) -> Array:
    var path_set: Dictionary = {}
    for c in wlr.path:
        path_set[c] = true
    var border: Dictionary = _flood_border(wlr.size, path_set)
    var tiles: Array = []
    for y in range(wlr.size.y):
        var row: Array[int] = []
        for x in range(wlr.size.x):
            var coord := Vector2i(x, y)
            var t: int = LevelResource.TileType.EMPTY
            if not path_set.has(coord):
                if wlr.obstacle_overrides.has(coord):
                    t = _override_tile(wlr.obstacle_overrides[coord])
                elif border.has(coord):
                    t = LevelResource.TileType.WALL
                else:
                    t = LevelResource.TileType.FLOWING_WATER
            row.append(t)
        tiles.append(row)
    return tiles

static func _flood_border(size: Vector2i, path_set: Dictionary) -> Dictionary:
    var border: Dictionary = {}
    var queue: Array[Vector2i] = []
    for x in range(size.x):
        _enqueue(Vector2i(x, 0), size, path_set, border, queue)
        _enqueue(Vector2i(x, size.y - 1), size, path_set, border, queue)
    for y in range(size.y):
        _enqueue(Vector2i(0, y), size, path_set, border, queue)
        _enqueue(Vector2i(size.x - 1, y), size, path_set, border, queue)
    while queue.size() > 0:
        var c: Vector2i = queue.pop_front()
        _enqueue(c + Vector2i(1, 0), size, path_set, border, queue)
        _enqueue(c + Vector2i(-1, 0), size, path_set, border, queue)
        _enqueue(c + Vector2i(0, 1), size, path_set, border, queue)
        _enqueue(c + Vector2i(0, -1), size, path_set, border, queue)
    return border

static func _enqueue(coord: Vector2i, size: Vector2i, path_set: Dictionary, border: Dictionary, queue: Array[Vector2i]) -> void:
    if coord.x < 0 or coord.x >= size.x or coord.y < 0 or coord.y >= size.y:
        return
    if path_set.has(coord) or border.has(coord):
        return
    border[coord] = true
    queue.append(coord)

static func _override_tile(value: Variant) -> int:
    if value == "WALL":
        return LevelResource.TileType.WALL
    if value == "FLOWING_WATER":
        return LevelResource.TileType.FLOWING_WATER
    return LevelResource.TileType.EMPTY
