class_name GridRenderer
extends Node2D

@export var cell_size: int = 64
var _grid_model: GridModel
var _mechanic_system: MechanicSystem
var _path_state: PathState

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_SWEPT := Color(0.42, 0.42, 0.42)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)

func bind(grid_model: GridModel, mechanic_system: MechanicSystem, path_state: PathState) -> void:
    _grid_model = grid_model
    _mechanic_system = mechanic_system
    _path_state = path_state
    _path_state.path_changed.connect(func(_p): queue_redraw())
    queue_redraw()

func _draw() -> void:
    if _grid_model == null:
        return
    for y in range(_grid_model.size.y):
        for x in range(_grid_model.size.x):
            var coord := Vector2i(x, y)
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            draw_rect(rect, _cell_color(coord), true)
            draw_rect(rect, COLOR_GRID, false)
    for c in _path_state.path:
        draw_rect(Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size), COLOR_SWEPT, true)

func _cell_color(coord: Vector2i) -> Color:
    var data: MechanicData = _mechanic_system.data_at(coord)
    if data is WallData:
        return COLOR_WALL
    if data is FlowingWaterData:
        return COLOR_WATER
    return COLOR_EMPTY
