class_name GridModel
extends Resource

var size: Vector2i
var _mechanic_at: Dictionary  # Vector2i -> MechanicData

func in_bounds(coord: Vector2i) -> bool:
    return coord.x >= 0 and coord.y >= 0 and coord.x < size.x and coord.y < size.y

func neighbors(coord: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    var deltas: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for d in deltas:
        var c: Vector2i = coord + d
        if in_bounds(c):
            result.append(c)
    return result

func set_mechanic_data(coord: Vector2i, data: MechanicData) -> void:
    _mechanic_at[coord] = data

func mechanic_data_at(coord: Vector2i) -> MechanicData:
    return _mechanic_at.get(coord)
