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
