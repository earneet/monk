class_name GridRenderer
extends Node2D

@export var cell_size: int = 64
var _grid_model: GridModel
var _mechanic_system: MechanicSystem
var _path_state: PathState

const FLOOR_PERIOD := 4  # floor.png 每 256px 含 4 个 64px 采样块,镜像衔接
const FLOOR_TILE := 64

const TEX_FLOOR := preload("res://assets/art/tiles/floor.png")
const TEX_WALLS: Array[Texture2D] = [
    preload("res://assets/art/tiles/wall_0.png"),
    preload("res://assets/art/tiles/wall_1.png"),
    preload("res://assets/art/tiles/wall_2.png"),
]
const TEX_STREAM := preload("res://assets/art/tiles/stream.png")
const TEX_POND := preload("res://assets/art/tiles/pond.png")
const TEX_LEVER := preload("res://assets/art/tiles/lever.png")
const TEX_DOOR := preload("res://assets/art/tiles/door.png")
const TEX_BRIDGE := preload("res://assets/art/tiles/bridge.png")
const TEX_PORTAL := preload("res://assets/art/tiles/portal.png")
const TEX_SWEPT := preload("res://assets/art/tiles/swept.png")

const TINT_INACTIVE := Color(0.5, 0.48, 0.45)
const TINT_DWATER_DEEP := Color(0.5, 0.62, 0.82)
const COLOR_SWEPT := Color(1.0, 1.0, 1.0, 0.55)
const COLOR_GRID := Color(0.1, 0.08, 0.05, 0.10)
const COLOR_PORTAL_LINK := Color(0.62, 0.42, 0.92, 0.65)
const COLOR_MAT := Color(0.94, 0.91, 0.83, 0.92)
const COLOR_MAT_BORDER := Color(0.35, 0.3, 0.24, 0.85)

func bind(grid_model: GridModel, mechanic_system: MechanicSystem, path_state: PathState) -> void:
    _grid_model = grid_model
    _mechanic_system = mechanic_system
    _path_state = path_state
    _path_state.path_changed.connect(func(_p): queue_redraw())
    queue_redraw()

func _draw() -> void:
    if _grid_model == null:
        return
    var board := Rect2(-8.0, -8.0, _grid_model.size.x * cell_size + 16.0, _grid_model.size.y * cell_size + 16.0)
    draw_rect(board, COLOR_MAT)
    draw_rect(board, COLOR_MAT_BORDER, false, 2.0)
    var obstacles: Dictionary = {}
    for y in range(_grid_model.size.y):
        for x in range(_grid_model.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = _mechanic_system.data_at(coord)
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            draw_texture_rect_region(TEX_FLOOR, rect, _floor_region(coord))
            if data == null:
                continue
            var kind := _kind_of(data)
            if kind == "":
                draw_texture_rect(_cell_texture(data), rect, false, _cell_tint(data, _path_state.path))
            else:
                if not obstacles.has(kind):
                    obstacles[kind] = {"cells": {}, "sample": data}
                (obstacles[kind]["cells"] as Dictionary)[coord] = true
    for kind: String in obstacles:
        _draw_obstacles(kind, obstacles[kind])
    for c in _path_state.path:
        if _mechanic_system.data_at(c) == null:
            draw_texture_rect(TEX_SWEPT, Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size), false, COLOR_SWEPT)
    _draw_grid_lines()
    _draw_portal_links()

func _floor_region(coord: Vector2i) -> Rect2:
    var px := _mirror_idx(coord.x, FLOOR_PERIOD) * FLOOR_TILE
    var py := _mirror_idx(coord.y, FLOOR_PERIOD) * FLOOR_TILE
    return Rect2(px, py, FLOOR_TILE, FLOOR_TILE)

func _mirror_idx(i: int, n: int) -> int:
    var m := posmod(i, n * 2)
    return m if m < n else n * 2 - 1 - m

func _kind_of(data: MechanicData) -> String:
    if data is WallData:
        return "wall"
    if data is FlowingWaterData:
        return "stream"
    if data is DynamicWaterData:
        return "pond"
    if data is PortalData:
        return "portal"
    return ""

func _draw_obstacles(kind: String, bucket: Dictionary) -> void:
    var cells: Dictionary = bucket["cells"]
    var used := {}
    for c in cells:
        if c is not Vector2i or used.has(c):
            continue
        var w := 1
        while cells.has(c + Vector2i(w, 0)) and not used.has(c + Vector2i(w, 0)):
            w += 1
        var h := 1
        while true:
            var row_ok := true
            for i in range(w):
                var p: Vector2i = c + Vector2i(i, h)
                if not cells.has(p) or used.has(p):
                    row_ok = false
                    break
            if not row_ok:
                break
            h += 1
        for iy in range(h):
            for ix in range(w):
                used[c + Vector2i(ix, iy)] = true
        var rect := Rect2(c.x * cell_size, c.y * cell_size, w * cell_size, h * cell_size)
        var hashv := absi((c.x * 7 + c.y * 13) * 2654435761)
        match kind:
            "wall":
                var variant := TEX_WALLS[(hashv + (1 if h > w else 0)) % TEX_WALLS.size()]
                var fit := rect.grow(-rect.size.x * 0.04)
                var t := Transform2D(0.0, Vector2(-1.0 if hashv % 2 == 0 else 1.0, 1.0), 0.0, fit.get_center())
                draw_set_transform_matrix(t)
                draw_texture_rect(variant, Rect2(-fit.size / 2.0, fit.size), false)
                draw_set_transform_matrix(Transform2D())
            "stream":
                if rect.size.x >= rect.size.y:
                    draw_texture_rect(TEX_STREAM, rect, false)
                else:
                    var t := Transform2D(TAU / 4.0, Vector2.ONE, 0.0, rect.get_center())
                    draw_set_transform_matrix(t)
                    draw_texture_rect(TEX_STREAM, Rect2(-Vector2(rect.size.y, rect.size.x) / 2.0, Vector2(rect.size.y, rect.size.x)), false)
                    draw_set_transform_matrix(Transform2D())
            "pond":
                var sample: MechanicData = bucket["sample"]
                var tint := _cell_tint(sample, _path_state.path)
                var fit := rect.grow(-rect.size.x * 0.08)
                draw_texture_rect(TEX_POND, fit, false, tint)
            "portal":
                draw_texture_rect(TEX_PORTAL, rect.grow(-rect.size.x * 0.04), false)

func _draw_grid_lines() -> void:
    for x in range(_grid_model.size.x + 1):
        draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, _grid_model.size.y * cell_size), COLOR_GRID, 1.0)
    for y in range(_grid_model.size.y + 1):
        draw_line(Vector2(0, y * cell_size), Vector2(_grid_model.size.x * cell_size, y * cell_size), COLOR_GRID, 1.0)

func _draw_portal_links() -> void:
    var font := ThemeDB.get_default_theme().default_font
    for pair in _mechanic_system.portal_pairs():
        var a: Vector2i = pair[0]
        var b: Vector2i = pair[1]
        var ca := Vector2((a.x + 0.5) * cell_size, (a.y + 0.5) * cell_size)
        var cb := Vector2((b.x + 0.5) * cell_size, (b.y + 0.5) * cell_size)
        draw_dashed_line(ca, cb, COLOR_PORTAL_LINK, 3.0, 10.0)
        for endpoint in [a, b]:
            var text_pos := Vector2((endpoint.x + 0.5) * cell_size - 6, (endpoint.y + 0.5) * cell_size - 10)
            draw_string_outline(font, text_pos, (_mechanic_system.data_at(endpoint) as PortalData).pair_id.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 3, Color(0.1, 0.05, 0.15))
            draw_string(font, text_pos, (_mechanic_system.data_at(endpoint) as PortalData).pair_id.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.85, 1.0))

func _cell_texture(data: MechanicData) -> Texture2D:
    if data is LeverData:
        return TEX_LEVER
    if data is DoorData:
        return TEX_DOOR
    if data is BridgeData:
        return TEX_BRIDGE
    if data is PortalData:
        return TEX_PORTAL
    return TEX_FLOOR

func _cell_tint(data: MechanicData, path: Array) -> Color:
    if data is DoorData:
        var open: bool = _mechanic_system.is_lever_pressed((data as DoorData).lever_ids, path)
        return Color.WHITE if open else TINT_INACTIVE
    if data is BridgeData:
        var placed: bool = _mechanic_system.is_lever_pressed((data as BridgeData).lever_ids, path)
        return Color.WHITE if placed else TINT_INACTIVE
    if data is DynamicWaterData:
        var dw := data as DynamicWaterData
        if dw.period < 2:
            return Color.WHITE
        var phase: int = path.size() % dw.period
        @warning_ignore("integer_division")
        var low: bool = phase < (dw.period + 1) / 2
        return Color.WHITE if low else TINT_DWATER_DEEP
    return Color.WHITE
