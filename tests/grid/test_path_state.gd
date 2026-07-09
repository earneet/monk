extends GutTest

func _ps(ms: MechanicSystem, gm: GridModel) -> PathState:
    var ps := PathState.new()
    ps.setup(ms, gm, Vector2i(0, 0))
    return ps

func _gm3() -> GridModel:
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    return gm

func test_move_valid_appends():
    var ps := _ps(MechanicSystem.new(), _gm3())
    assert_true(ps.move(Vector2i(1, 0)))
    assert_eq(ps.path.size(), 2)

func test_move_out_of_non_adjacent_fails():
    var ps := _ps(MechanicSystem.new(), _gm3())
    assert_false(ps.move(Vector2i(2, 2)))
    assert_eq(ps.path.size(), 1)

func test_move_repeat_fails():
    var ps := _ps(MechanicSystem.new(), _gm3())
    ps.move(Vector2i(1, 0))
    assert_false(ps.move(Vector2i(0, 0)))
    assert_eq(ps.path.size(), 2)

func test_move_into_wall_fails():
    var ms := MechanicSystem.new()
    ms.set_data(Vector2i(1, 0), WallData.new())
    var ps := _ps(ms, _gm3())
    assert_false(ps.move(Vector2i(1, 0)))

func test_undo_rolls_back():
    var ps := _ps(MechanicSystem.new(), _gm3())
    ps.move(Vector2i(1, 0))
    ps.undo()
    assert_eq(ps.path.size(), 1)
    assert_eq(ps.path[0], Vector2i(0, 0))

func test_is_covered():
    var gm := GridModel.new()
    gm.size = Vector2i(1, 2)
    var ps := _ps(MechanicSystem.new(), gm)
    ps.set_need_cover([Vector2i(0, 0), Vector2i(0, 1)])
    assert_false(ps.is_covered())
    ps.move(Vector2i(0, 1))
    assert_true(ps.is_covered())

func test_path_changed_signal():
    var ps := _ps(MechanicSystem.new(), _gm3())
    var received: Array = []
    ps.path_changed.connect(func(p: Array): received.append(p.duplicate()))
    ps.move(Vector2i(1, 0))
    assert_eq(received.size(), 1)
