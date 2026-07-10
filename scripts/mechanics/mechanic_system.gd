class_name MechanicSystem
extends Resource

var _data_at: Dictionary = {}  # Vector2i -> MechanicData
var _lever_cells: Dictionary = {}  # id(String) -> coord(Vector2i)
var _portal_pairs: Dictionary = {}

func set_data(coord: Vector2i, data: MechanicData) -> void:
    _data_at[coord] = data

func data_at(coord: Vector2i) -> MechanicData:
    return _data_at.get(coord)

func can_pass(coord: Vector2i, path: Array) -> bool:
    var data: MechanicData = data_at(coord)
    if data == null:
        return true
    return data.can_pass(path, self)

func register_lever(id: String, coord: Vector2i) -> void:
    _lever_cells[id] = coord

func is_lever_pressed(lever_ids: Array[String], path: Array) -> bool:
    for id in lever_ids:
        var c: Variant = _lever_cells.get(id)
        if c != null and c in path:
            return true
    return false

func register_portal(a: Vector2i, b: Vector2i) -> void:
    _portal_pairs[a] = b
    _portal_pairs[b] = a

func pair_of(coord: Vector2i) -> Vector2i:
    return _portal_pairs.get(coord, coord)

func portal_pairs() -> Array:
    var result: Array = []
    var seen: Dictionary = {}
    for key in _portal_pairs:
        var a: Vector2i = key
        var b: Vector2i = _portal_pairs[key]
        var k1 := "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]
        var k2 := "%d,%d-%d,%d" % [b.x, b.y, a.x, a.y]
        if not seen.has(k1) and not seen.has(k2):
            result.append([a, b])
            seen[k1] = true
    return result
