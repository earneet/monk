extends GutTest

func _wlr(size: Vector2i, path: Array[Vector2i], has_goal: bool) -> WorkLevelResource:
    var w := WorkLevelResource.new()
    w.size = size
    w.path = path
    w.has_goal = has_goal
    w.meta = LevelMeta.new()
    w.meta.id = "T1"
    w.meta.display_name = "Test"
    w.meta.difficulty = 1
    return w

func test_export_maps_fields_no_goal():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var lr := Exporter.export_level(_wlr(Vector2i(3, 1), p, false))
    assert_eq(lr.size, Vector2i(3, 1))
    assert_eq(lr.start, Vector2i(0, 0))
    assert_eq(lr.goal, Vector2i(-1, -1))
    assert_eq(lr.tiles.size(), 1)
    assert_eq(lr.tiles[0][0], LevelResource.TileType.EMPTY)
    assert_eq(lr.meta.id, "T1")

func test_export_goal_when_has_goal():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
    var lr := Exporter.export_level(_wlr(Vector2i(2, 1), p, true))
    assert_eq(lr.goal, Vector2i(1, 0))

func test_export_border_filled_wall():
    var p: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
    var lr := Exporter.export_level(_wlr(Vector2i(3, 3), p, false))
    assert_eq(lr.tiles[0][0], LevelResource.TileType.WALL)
    assert_eq(lr.tiles[1][1], LevelResource.TileType.EMPTY)
