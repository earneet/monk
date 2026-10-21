class_name PlayerSprite
extends Node2D

@export var cell_size: int = 64
@export var move_duration: float = 0.16

var _path_state: PathState
var _offset: Vector2 = Vector2.ZERO
var _tween: Tween
var _hop: float = 0.0

const TEX_MONK := preload("res://assets/art/player/monk.png")
const COLOR_SHADOW := Color(0.05, 0.05, 0.08, 0.30)
const HOP_HEIGHT := 0.22

func bind(path_state: PathState) -> void:
    _path_state = path_state
    if not _path_state.path_changed.is_connected(_update):
        _path_state.path_changed.connect(_update)
    _snap()

func set_offset(offset: Vector2) -> void:
    _offset = offset
    _snap()

func _target_pos() -> Vector2:
    if _path_state == null or _path_state.path.size() == 0:
        return position
    var last: Vector2i = _path_state.path[_path_state.path.size() - 1]
    @warning_ignore("integer_division")
    return _offset + Vector2(last * cell_size + Vector2i(cell_size / 2, cell_size / 2))

func _snap() -> void:
    if _tween != null:
        _tween.kill()
        _tween = null
    _hop = 0.0
    position = _target_pos()
    queue_redraw()

func _update(_p: Array = []) -> void:
    var target := _target_pos()
    var dist := position.distance_to(target) / float(cell_size)
    if is_zero_approx(dist):
        return
    if _tween != null:
        _tween.kill()
    _tween = create_tween().set_parallel(true)
    var dur := move_duration * clampf(1.0 + (dist - 1.0) * 0.4, 1.0, 1.8)
    _tween.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_method(_set_hop, _hop, 1.0, dur)
    _tween.chain().tween_callback(func(): _tween = null)

func _set_hop(v: float) -> void:
    _hop = v
    queue_redraw()

func _draw() -> void:
    var height := cell_size * 1.3
    var width := height * TEX_MONK.get_width() / float(TEX_MONK.get_height())
    var lift := sin(_hop * PI) * cell_size * HOP_HEIGHT
    draw_set_transform(Vector2(0, cell_size * 0.40), 0.0, Vector2(1.0, 0.38))
    draw_circle(Vector2.ZERO, width * 0.62 * (1.0 - sin(_hop * PI) * 0.25), COLOR_SHADOW)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_texture_rect(TEX_MONK, Rect2(-width / 2.0, -height * 0.62 - lift, width, height), false)
