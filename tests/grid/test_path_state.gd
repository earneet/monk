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

func test_move_into_portal_appends_peer():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(2, 0), Vector2i(2, 1))
    var px := PortalData.new()
    px.coord = Vector2i(2, 0)
    px.pair_id = "P1"
    ms.set_data(Vector2i(2, 0), px)
    var ps := _ps(ms, _gm3())
    assert_true(ps.move(Vector2i(1, 0)))
    assert_true(ps.move(Vector2i(2, 0)))
    assert_eq(ps.path.size(), 4)
    assert_eq(ps.path[2], Vector2i(2, 0))
    assert_eq(ps.path[3], Vector2i(2, 1))

func test_move_into_portal_peer_already_in_path_rolls_back():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(2, 0), Vector2i(1, 0))
    var px := PortalData.new()
    px.coord = Vector2i(2, 0)
    px.pair_id = "P1"
    ms.set_data(Vector2i(2, 0), px)
    var ps := _ps(ms, _gm3())
    ps.move(Vector2i(1, 0))
    var received: Array = []
    ps.path_changed.connect(func(p: Array): received.append(p.duplicate()))
    assert_false(ps.move(Vector2i(2, 0)))
    assert_eq(ps.path.size(), 2)
    assert_eq(received.size(), 0)

func _ps_with_portal_pair() -> PathState:
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(2, 0), Vector2i(2, 1))
    var px := PortalData.new()
    px.coord = Vector2i(2, 0)
    px.pair_id = "P1"
    ms.set_data(Vector2i(2, 0), px)
    return _ps(ms, _gm3())

func test_undo_portal_pair_rolls_back_two():
    var ps := _ps_with_portal_pair()
    ps.move(Vector2i(1, 0))
    ps.move(Vector2i(2, 0))
    ps.undo()
    assert_eq(ps.path.size(), 2)
    assert_eq(ps.path[1], Vector2i(1, 0))

func test_undo_consecutive_portals_only_last_intent():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(2, 0), Vector2i(2, 1))
    ms.register_portal(Vector2i(1, 1), Vector2i(1, 2))
    var p1 := PortalData.new()
    p1.coord = Vector2i(2, 0)
    p1.pair_id = "P1"
    ms.set_data(Vector2i(2, 0), p1)
    var p2 := PortalData.new()
    p2.coord = Vector2i(1, 1)
    p2.pair_id = "P2"
    ms.set_data(Vector2i(1, 1), p2)
    var ps := _ps(ms, _gm3())
    ps.move(Vector2i(1, 0))
    ps.move(Vector2i(2, 0))
    ps.move(Vector2i(1, 1))
    ps.undo()
    assert_eq(ps.path.size(), 4)
    assert_eq(ps.path[3], Vector2i(2, 1))
