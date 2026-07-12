extends GutTest

func test_exported_level_loadable_and_winnable():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = p
    w.has_goal = false
    var lr := Exporter.export_level(w)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_not_null(ls.grid_model)
    ls.path_state.move(Vector2i(1, 0))
    ls.path_state.move(Vector2i(2, 0))
    assert_true(ls.check_win())

func test_exported_level_with_mechanism_free():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = p
    w.has_goal = true
    var lr := Exporter.export_level(w)
    assert_eq(lr.goal, Vector2i(2, 0))
    assert_eq(lr.mechanics.size(), 0)
