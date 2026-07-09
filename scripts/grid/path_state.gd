class_name PathState
extends Resource

var path: Array[Vector2i] = []
var _ms: MechanicSystem
var _gm: GridModel
var _need_cover: Array[Vector2i] = []

signal path_changed(new_path: Array)

func setup(ms: MechanicSystem, gm: GridModel, start: Vector2i) -> void:
    _ms = ms
    _gm = gm
    path = [start]
    _emit()

func move(coord: Vector2i) -> bool:
    if not _gm.in_bounds(coord):
        return false
    if coord in path:
        return false
    if path.size() > 0:
        var last: Vector2i = path[path.size() - 1]
        if coord not in _gm.neighbors(last):
            return false
    if not _ms.can_pass(coord, path):
        return false
    path.append(coord)
    _emit()
    return true

func undo() -> void:
    if path.size() > 1:
        path.pop_back()
        _emit()

func is_covered() -> bool:
    for c in _need_cover:
        if c not in path:
            return false
    return true

func set_need_cover(cells: Array[Vector2i]) -> void:
    _need_cover = cells

func _emit() -> void:
    path_changed.emit(path.duplicate())
