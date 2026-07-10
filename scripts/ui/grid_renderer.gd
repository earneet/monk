class_name GridRenderer
extends Node2D

@export var cell_size: int = 64
var _grid_model: GridModel
var _mechanic_system: MechanicSystem
var _path_state: PathState

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_LEVER := Color(0.95, 0.78, 0.20)
const COLOR_DOOR := Color(0.45, 0.30, 0.20)
const COLOR_BRIDGE := Color(0.55, 0.40, 0.25)
const COLOR_DWATER_LOW := Color(0.62, 0.78, 0.84)
const COLOR_DWATER_HIGH := Color(0.30, 0.45, 0.55)
const COLOR_PORTAL := Color(0.55, 0.35, 0.70)
const COLOR_SWEPT := Color(0.42, 0.42, 0.42, 0.45)
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
            draw_rect(rect, _cell_color(coord, _path_state.path), true)
            draw_rect(rect, COLOR_GRID, false)
    for c in _path_state.path:
        draw_rect(Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size), COLOR_SWEPT, true)
    var font := ThemeDB.get_default_theme().default_font
    for pair in _mechanic_system.portal_pairs():
        var a: Vector2i = pair[0]
        var b: Vector2i = pair[1]
        var ca := Vector2((a.x + 0.5) * cell_size, (a.y + 0.5) * cell_size)
        var cb := Vector2((b.x + 0.5) * cell_size, (b.y + 0.5) * cell_size)
        draw_line(ca, cb, COLOR_PORTAL, 2.0)
    for y in range(_grid_model.size.y):
        for x in range(_grid_model.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = _mechanic_system.data_at(coord)
            if data is PortalData:
                var center := Vector2((x + 0.5) * cell_size - 6, (y + 0.5) * cell_size - 8)
                draw_string(font, center, (data as PortalData).pair_id.substr(0, 1), 0, -1, 16)

func _cell_color(coord: Vector2i, path: Array) -> Color:
    var data: MechanicData = _mechanic_system.data_at(coord)
    if data is WallData:
        return COLOR_WALL
    if data is FlowingWaterData:
        return COLOR_WATER
    if data is LeverData:
        return COLOR_LEVER
    if data is DoorData:
        var open: bool = _mechanic_system.is_lever_pressed((data as DoorData).lever_ids, path)
        return COLOR_DOOR if open else COLOR_DOOR.darkened(0.35)
    if data is BridgeData:
        var placed: bool = _mechanic_system.is_lever_pressed((data as BridgeData).lever_ids, path)
        return COLOR_BRIDGE if placed else COLOR_BRIDGE.darkened(0.35)
    if data is DynamicWaterData:
        var dw := data as DynamicWaterData
        var phase: int = path.size() % dw.period
        var low: bool = phase < (dw.period + 1) / 2
        return COLOR_DWATER_LOW if low else COLOR_DWATER_HIGH
    if data is PortalData:
        return COLOR_PORTAL
    return COLOR_EMPTY
