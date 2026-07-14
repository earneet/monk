class_name LevelController
extends Node

@export var level: LevelResource
@export var cell_size: int = 64

signal won()
signal back_requested()

var _won: bool = false

@onready var _input_system: InputSystem = $InputSystem
@onready var _grid_renderer: GridRenderer = $GridRenderer
@onready var _player_sprite: PlayerSprite = $PlayerSprite
@onready var _hud: HUD = $HUD

var _level_system: LevelSystem
var _path_state: PathState
var _grid_model: GridModel
var _mechanic_system: MechanicSystem

func _ready() -> void:
    _level_system = LevelSystem.new()
    _level_system.load(level)
    _bind_all()
    _input_system.move_intent.connect(_on_move_intent)
    _input_system.undo_request.connect(_on_undo)
    _input_system.reset_request.connect(_on_reset)
    _hud.undo_pressed.connect(_on_undo)
    _hud.reset_pressed.connect(_on_reset)
    _path_state.path_changed.connect(_check_win)
    _hud.back_pressed.connect(func(): back_requested.emit())
    _check_win([])

func _bind_all() -> void:
    _path_state = _level_system.path_state
    _grid_model = _level_system.grid_model
    _mechanic_system = _level_system.mechanic_system
    _input_system.cell_size = cell_size
    _input_system.bind(_path_state, _grid_model)
    _grid_renderer.cell_size = cell_size
    _grid_renderer.bind(_grid_model, _mechanic_system, _path_state)
    _player_sprite.cell_size = cell_size
    _player_sprite.bind(_path_state)
    var grid_pixel := Vector2(_grid_model.size.x * cell_size, _grid_model.size.y * cell_size)
    var offset: Vector2 = (_grid_renderer.get_viewport_rect().size - grid_pixel) / 2.0
    _grid_renderer.position = offset
    _player_sprite.set_offset(offset)
    _input_system.set_offset(offset)

func _on_move_intent(coord: Vector2i) -> void:
    _path_state.move(coord)

func _on_undo() -> void:
    _path_state.undo()

func _on_reset() -> void:
    _level_system.load(level)
    _bind_all()
    _path_state.path_changed.connect(_check_win)
    _check_win([])

func _check_win(_p: Array) -> void:
    if _level_system.check_win():
        if not _won:
            _won = true
            won.emit()
        _hud.show_win()
    else:
        _won = false
        _hud.clear_win()
