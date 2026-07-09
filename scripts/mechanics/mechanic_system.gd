class_name MechanicSystem
extends Resource

var _data_at: Dictionary = {}  # Vector2i -> MechanicData

func set_data(coord: Vector2i, data: MechanicData) -> void:
    _data_at[coord] = data

func data_at(coord: Vector2i) -> MechanicData:
    return _data_at.get(coord)

func can_pass(coord: Vector2i, _path: Array) -> bool:
    var data: MechanicData = data_at(coord)
    if data == null:
        return true
    if data is WallData:
        return false
    if data is FlowingWaterData:
        return false
    return true
