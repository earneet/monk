class_name PlayerSprite
extends Node2D

@export var cell_size: int = 64
var _path_state: PathState
var _offset: Vector2 = Vector2.ZERO

const TEX_MONK := preload("res://assets/art/player/monk.png")
const COLOR_SHADOW := Color(0.05, 0.05, 0.08, 0.30)

func bind(path_state: PathState) -> void:
    _path_state = path_state
    _path_state.path_changed.connect(_update)
    _update()

func set_offset(offset: Vector2) -> void:
    _offset = offset
    _update()

func _update(_p: Array = []) -> void:
    if _path_state.path.size() > 0:
        var last: Vector2i = _path_state.path[_path_state.path.size() - 1]
        @warning_ignore("integer_division")
        position = _offset + Vector2(last * cell_size + Vector2i(cell_size / 2, cell_size / 2))
    queue_redraw()

func _draw() -> void:
    var height := cell_size * 1.3
    var width := height * TEX_MONK.get_width() / float(TEX_MONK.get_height())
    draw_set_transform(Vector2(0, cell_size * 0.40), 0.0, Vector2(1.0, 0.38))
    draw_circle(Vector2.ZERO, width * 0.62, COLOR_SHADOW)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_texture_rect(TEX_MONK, Rect2(-width / 2.0, -height * 0.62, width, height), false)
