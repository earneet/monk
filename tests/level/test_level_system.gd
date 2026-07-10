extends GutTest

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

func test_build_flat_grid():
    var ls := LevelSystem.new()
    ls.load(_flat_level(2, 2))
    assert_not_null(ls.grid_model)
    assert_eq(ls.grid_model.size, Vector2i(2, 2))

func test_need_cover_excludes_walls():
    var lr := _flat_level(3, 1)
    lr.tiles[0][1] = LevelResource.TileType.WALL
    var ls := LevelSystem.new()
    ls.load(lr)
    var nc := ls.need_cover()
    assert_false(nc.has(Vector2i(1, 0)))
    assert_true(nc.has(Vector2i(0, 0)))
    assert_true(nc.has(Vector2i(2, 0)))

func test_check_win_when_covered():
    var lr := _flat_level(2, 1)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_false(ls.check_win())
    ls.path_state.move(Vector2i(1, 0))
    assert_true(ls.check_win())

func test_need_cover_includes_mechanism_cells():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    ls.load(lr)
    var nc := ls.need_cover()
    assert_true(nc.has(Vector2i(1, 0)))
    assert_true(nc.has(Vector2i(2, 0)))

func test_door_opens_after_stepping_lever():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_false(ls.path_state.move(Vector2i(2, 0)))
    ls.path_state.move(Vector2i(1, 0))
    assert_true(ls.path_state.move(Vector2i(2, 0)))

func test_validate_rejects_period_lt_2():
    var lr := _flat_level(3, 1)
    var dw := DynamicWaterData.new()
    dw.coord = Vector2i(1, 0)
    dw.period = 1
    lr.mechanics.append(dw)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("period") >= 0))

func test_validate_rejects_empty_lever_ids():
    var lr := _flat_level(3, 1)
    var door := DoorData.new()
    door.coord = Vector2i(1, 0)
    door.lever_ids = []
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("lever_ids") >= 0))

func test_validate_rejects_unknown_lever_ref():
    var lr := _flat_level(3, 1)
    var door := DoorData.new()
    door.coord = Vector2i(1, 0)
    door.lever_ids = ["NOPE"]
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("NOPE") >= 0))

func test_validate_accepts_valid_level():
    var lr := _flat_level(3, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    assert_eq(ls.validate(lr), [])

func test_validate_accepts_bridge():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(3, 0)
    bridge.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(bridge)
    var ls := LevelSystem.new()
    assert_eq(ls.validate(lr), [])

func _portal(pair_id: String, coord: Vector2i) -> PortalData:
    var p := PortalData.new()
    p.pair_id = pair_id
    p.coord = coord
    return p

func test_load_registers_portal_pair():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_eq(ls.mechanic_system.pair_of(Vector2i(1, 0)), Vector2i(2, 0))
    assert_eq(ls.mechanic_system.pair_of(Vector2i(2, 0)), Vector2i(1, 0))

func test_validate_rejects_lone_pair_id():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("成对") >= 0))

func test_validate_rejects_triple_pair_id():
    var lr := _flat_level(4, 1)
    lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(3, 0)))
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("成对") >= 0))

func test_validate_rejects_empty_pair_id():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("", Vector2i(1, 0)))
    lr.mechanics.append(_portal("", Vector2i(2, 0)))
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("不能为空") >= 0))

func test_validate_rejects_same_coord_pair():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("不能相同") >= 0))

func test_validate_rejects_start_as_portal():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("P1", Vector2i(0, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
    lr.start = Vector2i(0, 0)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("起点") >= 0))

func test_validate_rejects_goal_as_portal():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("P1", Vector2i(0, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
    lr.start = Vector2i(1, 0)
    lr.goal = Vector2i(2, 0)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("终点") >= 0))

func test_validate_accepts_valid_portal():
    var lr := _flat_level(3, 1)
    lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
    lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
    var ls := LevelSystem.new()
    assert_eq(ls.validate(lr), [])

func test_bridge_crossable_after_stepping_lever():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(2, 0)
    bridge.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(bridge)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_true(ls.path_state.move(Vector2i(1, 0)))
    assert_true(ls.path_state.move(Vector2i(2, 0)))

func test_bridge_blocked_before_stepping_lever():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(3, 0)
    lever.id = "L1"
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(2, 0)
    bridge.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(bridge)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_true(ls.path_state.move(Vector2i(1, 0)))
    assert_false(ls.path_state.move(Vector2i(2, 0)))

func test_dynamic_water_low_phase_passable():
    var lr := _flat_level(3, 1)
    var dw := DynamicWaterData.new()
    dw.coord = Vector2i(2, 0)
    dw.period = 2
    lr.mechanics.append(dw)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_true(ls.path_state.move(Vector2i(1, 0)))
    assert_true(ls.path_state.move(Vector2i(2, 0)))

func test_dynamic_water_high_phase_blocks_first_step():
    var lr := _flat_level(2, 1)
    var dw := DynamicWaterData.new()
    dw.coord = Vector2i(1, 0)
    dw.period = 2
    lr.mechanics.append(dw)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_false(ls.path_state.move(Vector2i(1, 0)))
