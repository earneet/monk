extends GutTest

const LEVEL_PATH := "res://resources/levels/test_level_03.tres"

func _load() -> LevelSystem:
    var lr := load(LEVEL_PATH) as LevelResource
    var ls := LevelSystem.new()
    ls.load(lr)
    return ls

func test_load_portal_pair_registered():
    var ls := _load()
    assert_eq(ls.mechanic_system.pair_of(Vector2i(2, 0)), Vector2i(2, 1))
    assert_eq(ls.mechanic_system.pair_of(Vector2i(2, 1)), Vector2i(2, 0))

func test_move_into_portal_appends_peer():
    var ls := _load()
    var ps := ls.path_state
    assert_true(ps.move(Vector2i(1, 0)))
    assert_true(ps.move(Vector2i(2, 0)))
    assert_eq(ps.path.size(), 4)
    assert_eq(ps.path[3], Vector2i(2, 1))

func test_portal_level_solvable_cover_all():
    var ls := _load()
    var ps := ls.path_state
    ps.move(Vector2i(1, 0))
    ps.move(Vector2i(2, 0))
    ps.move(Vector2i(1, 1))
    ps.move(Vector2i(0, 1))
    assert_true(ls.check_win())
