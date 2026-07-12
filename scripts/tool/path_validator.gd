class_name PathValidator

static func validate(path: Array[Vector2i], size: Vector2i) -> Array[String]:
    var errors: Array[String] = []
    var seen: Dictionary = {}
    for i in range(path.size()):
        var c: Vector2i = path[i]
        if c.x < 0 or c.x >= size.x or c.y < 0 or c.y >= size.y:
            errors.append("路径格 (%d,%d) 越出网格 %s" % [c.x, c.y, size])
        if seen.has(c):
            errors.append("路径格 (%d,%d) 重复" % [c.x, c.y])
        seen[c] = true
        if i > 0:
            var prev: Vector2i = path[i - 1]
            if abs(c.x - prev.x) + abs(c.y - prev.y) != 1:
                errors.append("路径格 (%d,%d) 与前一格 (%d,%d) 非正交邻接" % [c.x, c.y, prev.x, prev.y])
    return errors
