extends GutTest

func _wlr(size: Vector2i, path: Array[Vector2i]) -> WorkLevelResource:
    var w := WorkLevelResource.new()
    w.size = size
    w.path = path
    return w

func test_path_cells_empty():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var tiles := Filler.fill(_wlr(Vector2i(3, 1), p))
    assert_eq(tiles.size(), 1)
    assert_eq(tiles[0].size(), 3)
    for x in range(3):
        assert_eq(tiles[0][x], LevelResource.TileType.EMPTY)

func test_border_non_path_filled_wall():
    var p: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
    var tiles := Filler.fill(_wlr(Vector2i(3, 3), p))
    assert_eq(tiles[0][0], LevelResource.TileType.WALL)
    assert_eq(tiles[2][2], LevelResource.TileType.WALL)
    assert_eq(tiles[1][1], LevelResource.TileType.EMPTY)

func test_inner_enclosed_filled_water():
    var p: Array[Vector2i] = [
        Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
        Vector2i(2, 1),
        Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2),
        Vector2i(0, 1)
    ]
    var tiles := Filler.fill(_wlr(Vector2i(3, 3), p))
    assert_eq(tiles[1][1], LevelResource.TileType.FLOWING_WATER)

func test_obstacle_override_replaces_default_fill():
    var p: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
    var w := _wlr(Vector2i(3, 3), p)
    w.obstacle_overrides[Vector2i(0, 0)] = "FLOWING_WATER"
    var t := Filler.fill(w)
    assert_eq(t[0][0], LevelResource.TileType.FLOWING_WATER)
