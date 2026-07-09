class_name PlayerSprite
extends Node2D

@export var cell_size: int = 64
var _path_state: PathState

const COLOR_PLAYER := Color(0.76, 0.27, 0.18)

func bind(path_state: PathState) -> void:
    _path_state = path_state
    _path_state.path_changed.connect(_update)
    _update()

func _update(_p: Array = []) -> void:
    if _path_state.path.size() > 0:
        var last: Vector2i = _path_state.path[_path_state.path.size() - 1]
        position = (last * cell_size) + Vector2i(cell_size / 2, cell_size / 2)
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, cell_size * 0.3, COLOR_PLAYER)
