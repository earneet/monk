@tool
class_name LevelCanvas
extends Control

var work: WorkLevelResource
var cell_size: int = 48

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_PATH := Color(0.95, 0.78, 0.20, 0.65)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)

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

func _gui_input(event: InputEvent) -> void:
    if work == null:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var coord := Vector2i(int(event.position.x / cell_size), int(event.position.y / cell_size))
        if coord.x < 0 or coord.x >= work.size.x or coord.y < 0 or coord.y >= work.size.y:
            return
        if coord in work.path:
            return
        if work.path.size() > 0:
            var last: Vector2i = work.path[work.path.size() - 1]
            if abs(coord.x - last.x) + abs(coord.y - last.y) != 1:
                return
        work.path.append(coord)
        queue_redraw()
