@tool
class_name LevelCanvas
extends Control

enum Mode { NONE, LEVER, DOOR, PORTAL, BRIDGE, DWATER }

var work: WorkLevelResource
var cell_size: int = 48
var mode: Mode = Mode.NONE
var mech_lever_ids: Array[String] = []
var mech_period: int = 4

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_PATH := Color(0.95, 0.78, 0.20, 0.65)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)
const COLOR_LEVER := Color(0.95, 0.78, 0.20)
const COLOR_DOOR := Color(0.45, 0.30, 0.20)
const COLOR_BRIDGE := Color(0.55, 0.40, 0.25)
const COLOR_DWATER := Color(0.62, 0.78, 0.84)
const COLOR_PORTAL := Color(0.55, 0.35, 0.70)

func _draw() -> void:
    if work == null:
        return
    var tiles := Filler.fill(work)
    for y in range(work.size.y):
        for x in range(work.size.x):
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            var t: int = tiles[y][x]
            var color: Color = COLOR_EMPTY
            if t == LevelResource.TileType.WALL:
                color = COLOR_WALL
            elif t == LevelResource.TileType.FLOWING_WATER:
                color = COLOR_WATER
            draw_rect(rect, color, true)
            draw_rect(rect, COLOR_GRID, false)
    for c in work.path:
        var rect := Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size)
        draw_rect(rect, COLOR_PATH, true)
    var font := ThemeDB.get_default_theme().default_font
    for m in work.mechanics:
        var c: Vector2i = m.coord
        var rect := Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size)
        var color: Color = COLOR_EMPTY
        var label := ""
        if m is LeverData:
            color = COLOR_LEVER
            label = (m as LeverData).id
        elif m is DoorData:
            color = COLOR_DOOR
        elif m is BridgeData:
            color = COLOR_BRIDGE
        elif m is PortalData:
            color = COLOR_PORTAL
            label = (m as PortalData).pair_id
        elif m is DynamicWaterData:
            color = COLOR_DWATER
        draw_rect(rect, color, true)
        if label != "":
            draw_string(font, Vector2(c.x * cell_size + 4, c.y * cell_size + 16), label.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _gui_input(event: InputEvent) -> void:
    if work == null:
        return
    if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        return
    var coord := Vector2i(int(event.position.x / cell_size), int(event.position.y / cell_size))
    if coord.x < 0 or coord.x >= work.size.x or coord.y < 0 or coord.y >= work.size.y:
        return
    if mode == Mode.NONE:
        _try_append(coord)
    elif coord in work.path:
        _annotate(coord)

func _try_append(coord: Vector2i) -> void:
    if coord in work.path:
        return
    if work.path.size() > 0:
        var last: Vector2i = work.path[work.path.size() - 1]
        if abs(coord.x - last.x) + abs(coord.y - last.y) != 1:
            return
    work.push_undo(func(): work.path.pop_back())
    work.path.append(coord)
    queue_redraw()

func _annotate(coord: Vector2i) -> void:
    for i in range(work.mechanics.size()):
        var m: MechanicData = work.mechanics[i]
        if m.coord == coord and _matches_mode(m):
            var captured: MechanicData = m
            var captured_idx: int = i
            work.push_undo(func(): work.mechanics.insert(captured_idx, captured))
            work.mechanics.remove_at(i)
            queue_redraw()
            return
    var data: MechanicData = _make_mechanic(coord)
    if data != null:
        work.push_undo(func(): work.mechanics.erase(data))
        work.mechanics.append(data)
        queue_redraw()

func _matches_mode(m: MechanicData) -> bool:
    match mode:
        Mode.LEVER: return m is LeverData
        Mode.DOOR: return m is DoorData
        Mode.BRIDGE: return m is BridgeData
        Mode.PORTAL: return m is PortalData
        Mode.DWATER: return m is DynamicWaterData
    return false

func _make_mechanic(coord: Vector2i) -> MechanicData:
    match mode:
        Mode.LEVER:
            var d := LeverData.new()
            d.id = _next_lever_id()
            d.coord = coord
            return d
        Mode.DOOR:
            var d := DoorData.new()
            d.lever_ids = mech_lever_ids
            d.coord = coord
            return d
        Mode.BRIDGE:
            var d := BridgeData.new()
            d.lever_ids = mech_lever_ids
            d.coord = coord
            return d
        Mode.PORTAL:
            var d := PortalData.new()
            d.pair_id = _next_pair_id()
            d.coord = coord
            return d
        Mode.DWATER:
            var d := DynamicWaterData.new()
            d.period = mech_period
            d.coord = coord
            return d
    return null

func _next_lever_id() -> String:
    var max_n := 0
    for m in work.mechanics:
        if m is LeverData:
            var s := (m as LeverData).id
            if s.begins_with("L"):
                var n := s.substr(1).to_int()
                if n > max_n:
                    max_n = n
    return "L" + str(max_n + 1)

func _next_pair_id() -> String:
    var count := 0
    var last_pair := ""
    for m in work.mechanics:
        if m is PortalData:
            count += 1
            last_pair = (m as PortalData).pair_id
    if count % 2 == 0:
        return "P" + str(count / 2 + 1)
    return last_pair
