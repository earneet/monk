class_name MechanicSystem
extends Resource

var _data_at: Dictionary = {}  # Vector2i -> MechanicData
var _lever_cells: Dictionary = {}  # id(String) -> coord(Vector2i)

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

func is_lever_pressed(lever_ids: Array, path: Array) -> bool:
    for id in lever_ids:
        var c: Variant = _lever_cells.get(id)
        if c != null and c in path:
            return true
    return false
