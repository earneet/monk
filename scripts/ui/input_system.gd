class_name InputSystem
extends Node

signal move_intent(coord: Vector2i)
signal undo_request()
signal reset_request()

@export var cell_size: int = 64

var _path_state: PathState
var _grid_model: GridModel

func bind(path_state: PathState, grid_model: GridModel) -> void:
    _path_state = path_state
    _grid_model = grid_model

func _unhandled_input(event: InputEvent) -> void:
    if _path_state == null or _grid_model == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        _handle_key(event.keycode)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_click(event.position)

func _handle_key(code: int) -> void:
    if code == KEY_Z:
        undo_request.emit()
        return
    if code == KEY_R:
        reset_request.emit()
        return
    var d: Vector2i = Vector2i.ZERO
    match code:
        KEY_LEFT, KEY_A: d = Vector2i(-1, 0)
        KEY_RIGHT, KEY_D: d = Vector2i(1, 0)
        KEY_UP, KEY_W: d = Vector2i(0, -1)
        KEY_DOWN, KEY_S: d = Vector2i(0, 1)
        _: return
    _emit_from_delta(d)

func _handle_click(world_pos: Vector2) -> void:
    var coord: Vector2i = Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))
    move_intent.emit(coord)

func _emit_from_delta(d: Vector2i) -> void:
    if _path_state.path.size() == 0:
        return
    var last: Vector2i = _path_state.path[_path_state.path.size() - 1]
    move_intent.emit(last + d)
