extends GutTest

func test_undo_executes_last_callback():
    var w := WorkLevelResource.new()
    w.path = [Vector2i(0, 0), Vector2i(1, 0)]
    w.push_undo(func(): w.path.pop_back())
    assert_true(w.undo())
    assert_eq(w.path.size(), 1)

func test_undo_multiple_lifo():
    var w := WorkLevelResource.new()
    w.path.append(Vector2i(0, 0))
    w.push_undo(func(): w.path.pop_back())
    w.path.append(Vector2i(1, 0))
    w.push_undo(func(): w.path.pop_back())
    w.undo()
    assert_eq(w.path.size(), 1)
    assert_eq(w.path[0], Vector2i(0, 0))
    w.undo()
    assert_eq(w.path.size(), 0)

func test_undo_empty_stack_returns_false():
    var w := WorkLevelResource.new()
    assert_false(w.undo())

func test_undo_restores_removed_mechanic():
    var w := WorkLevelResource.new()
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(0, 0)
    w.mechanics.append(lever)
    w.push_undo(func(): w.mechanics.insert(0, lever))
    w.mechanics.remove_at(0)
    assert_eq(w.mechanics.size(), 0)
    w.undo()
    assert_eq(w.mechanics.size(), 1)
