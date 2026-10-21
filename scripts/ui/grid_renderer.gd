class_name GridRenderer
extends Node2D

@export var cell_size: int = 64
var _grid_model: GridModel
var _mechanic_system: MechanicSystem
var _path_state: PathState

const TEX_FLOOR := preload("res://assets/art/tiles/floor.png")
const TEX_WALL := preload("res://assets/art/tiles/wall.png")
const TEX_WATER := preload("res://assets/art/tiles/water.png")
const TEX_LEVER := preload("res://assets/art/tiles/lever.png")
const TEX_DOOR := preload("res://assets/art/tiles/door.png")
const TEX_BRIDGE := preload("res://assets/art/tiles/bridge.png")
const TEX_DWATER := preload("res://assets/art/tiles/dwater.png")
const TEX_PORTAL := preload("res://assets/art/tiles/portal.png")
const TEX_SWEPT := preload("res://assets/art/tiles/swept.png")

const TINT_INACTIVE := Color(0.5, 0.48, 0.45)
const TINT_DWATER_DEEP := Color(0.42, 0.55, 0.78)
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
    draw_texture_rect(TEX_FLOOR, Rect2(Vector2.ZERO, Vector2(_grid_model.size) * cell_size), false)
    var scatter: Dictionary = {}
    for y in range(_grid_model.size.y):
        for x in range(_grid_model.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = _mechanic_system.data_at(coord)
            if data == null:
                continue
            var tex := _cell_texture(coord)
            if _is_scatter(tex):
                if not scatter.has(tex):
                    scatter[tex] = {}
                var bucket: Dictionary = scatter[tex]
                bucket[coord] = true
                if not bucket.has("sample"):
                    bucket["sample"] = data
            else:
                var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
                draw_texture_rect(tex, rect, false, _cell_tint(data, _path_state.path))
    for tex: Texture2D in scatter:
        _draw_merged(tex, scatter[tex])
    for c in _path_state.path:
        if _mechanic_system.data_at(c) == null:
            draw_texture_rect(TEX_SWEPT, Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size), false, COLOR_SWEPT)
    _draw_grid_lines()
    _draw_portal_links()

func _is_scatter(tex: Texture2D) -> bool:
    return tex == TEX_WALL or tex == TEX_WATER or tex == TEX_DWATER

func _draw_merged(tex: Texture2D, cells: Dictionary) -> void:
    # 贪心合并同行同宽的相邻格为整块矩形，消除格间接缝（岩石成片、水道成河）
    var tint := _cell_tint(cells.get("sample"), _path_state.path) if tex == TEX_DWATER else Color.WHITE
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
        var flip := absi((c.x * 7 + c.y * 13) * 2654435761) % 4
        var t := Transform2D(0.0, Vector2(-1.0 if flip % 2 == 0 else 1.0, -1.0 if flip >= 2 else 1.0), 0.0, rect.get_center())
        draw_set_transform_matrix(t)
        draw_texture_rect(tex, Rect2(-rect.size / 2.0, rect.size), false, tint)
        draw_set_transform_matrix(Transform2D())

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

func _cell_texture(coord: Vector2i) -> Texture2D:
    var data: MechanicData = _mechanic_system.data_at(coord)
    if data is WallData:
        return TEX_WALL
    if data is FlowingWaterData:
        return TEX_WATER
    if data is LeverData:
        return TEX_LEVER
    if data is DoorData:
        return TEX_DOOR
    if data is BridgeData:
        return TEX_BRIDGE
    if data is DynamicWaterData:
        return TEX_DWATER
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
