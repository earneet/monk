extends GutTest

const LevelScene := preload("res://Scenes/level.tscn")

func _flat_level(w: int, h: int) -> LevelResource:
    var lr := LevelResource.new()
    lr.size = Vector2i(w, h)
    lr.tiles.clear()
    for y in range(h):
        var row: Array[int] = []
        for x in range(w):
            row.append(LevelResource.TileType.EMPTY)
        lr.tiles.append(row)
    lr.start = Vector2i(0, 0)
    lr.goal = Vector2i(-1, -1)
    return lr

func _make_ctrl(w: int, h: int) -> Node:
    var ctrl := LevelScene.instantiate()
    ctrl.level = _flat_level(w, h)
    add_child(ctrl)
    return ctrl

func test_won_emits_once_on_cover():
    var ctrl := _make_ctrl(2, 1)
    var count := [0]
    ctrl.won.connect(func(): count[0] += 1)
    ctrl._on_move_intent(Vector2i(1, 0))
    assert_eq(count[0], 1)

func test_won_does_not_reemit_on_redundant_move():
    var ctrl := _make_ctrl(2, 1)
    var count := [0]
    ctrl.won.connect(func(): count[0] += 1)
    ctrl._on_move_intent(Vector2i(1, 0))
    ctrl._on_move_intent(Vector2i(1, 0))
    assert_eq(count[0], 1)

func test_won_resets_after_reset_request():
    var ctrl := _make_ctrl(2, 1)
    var count := [0]
    ctrl.won.connect(func(): count[0] += 1)
    ctrl._on_move_intent(Vector2i(1, 0))
    ctrl._on_reset()
    ctrl._on_move_intent(Vector2i(1, 0))
    assert_eq(count[0], 2)

func test_back_requested_emits_on_hud_back():
    var ctrl := _make_ctrl(2, 1)
    var emitted := [false]
    ctrl.back_requested.connect(func(): emitted[0] = true)
    ctrl._hud.back_pressed.emit()
    assert_true(emitted[0])
