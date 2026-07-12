extends GutTest

func test_undo_pops_last_path_cell():
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    assert_true(w.undo_last_step())
    assert_eq(w.path.size(), 2)
    assert_eq(w.path[w.path.size() - 1], Vector2i(1, 0))

func test_undo_removes_mechanic_on_popped_cell():
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = [Vector2i(0, 0), Vector2i(1, 0)]
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(1, 0)
    w.mechanics.append(lever)
    w.undo_last_step()
    assert_eq(w.path.size(), 1)
    assert_eq(w.mechanics.size(), 0)

func test_undo_empty_path_returns_false():
    var w := WorkLevelResource.new()
    w.path = []
    assert_false(w.undo_last_step())
