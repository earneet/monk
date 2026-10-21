extends Node

# 动画专用探针:独立场景摆拍 PlayerSprite 的 idle/walk 每一帧与滑动中间相,
# 不进主关卡场景。产物在 .zcode/shots/anim_*.png,供逐帧连续性审查。
# 运行:godot --path . res://tests/visual/anim_probe.tscn(或经 godot-mcp)

const SHOT_DIR := "res://.zcode/shots"
const PlayerSpriteScene := preload("res://scripts/ui/player_sprite.gd")

var _sprite: PlayerSprite
var _bg: ColorRect

func _ready() -> void:
    get_window().size = Vector2i(1280, 720)
    _bg = ColorRect.new()
    _bg.color = Color(0.93, 0.9, 0.82)
    _bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_bg)
    _sprite = PlayerSpriteScene.new()
    _sprite.cell_size = 72
    _sprite.position = Vector2(640, 400)
    add_child(_sprite)
    await _shoot_idle_frames()
    await _shoot_walk_frames()
    await _shoot_slide_sequence()
    get_tree().quit()

func _pose(frame: int, moving: bool, hop: float = 0.0, face: float = 1.0) -> void:
    _sprite._moving = moving
    _sprite._frame = frame
    _sprite._hop = hop
    _sprite._face = face
    _sprite.queue_redraw()
    await RenderingServer.frame_post_draw

func _snap(shot_name: String) -> void:
    await RenderingServer.frame_post_draw
    var dir := ProjectSettings.globalize_path(SHOT_DIR)
    DirAccess.make_dir_recursive_absolute(dir)
    get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
    print("[shot] ", shot_name)

func _place(center: Vector2) -> void:
    _sprite.position = center
    _sprite._offset = Vector2.ZERO

func _shoot_idle_frames() -> void:
    _place(Vector2(640, 400))
    for i in range(PlayerSprite.FRAMES_IDLE.size()):
        _sprite._anim_time = float(i) / PlayerSprite.IDLE_FPS
        await _pose(i, false)
        await _snap("anim_idle_%d" % i)

func _shoot_walk_frames() -> void:
    for i in range(PlayerSprite.FRAMES_WALK.size()):
        _place(Vector2(640, 400))
        _sprite._anim_time = float(i) / PlayerSprite.WALK_FPS
        await _pose(i, true, 0.25)
        await _snap("anim_walk_%d" % i)

func _shoot_slide_sequence() -> void:
    # 从 (2,2) 滑向 (5,2),取 25%/50%/75% 三个中间相验证滑动+跳跃+影子
    var from := Vector2(400, 400)
    var to := Vector2(616, 400)
    for prog in [0.25, 0.5, 0.75]:
        _place(from.lerp(to, prog))
        await _pose(0, true, sin(prog * PI), -1.0)
        await _snap("anim_slide_%d" % int(prog * 100))
