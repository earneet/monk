extends GutTest

func test_annotated_door_level_exportable_and_winnable():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = path
    w.has_goal = false
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(1, 0)
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    door.coord = Vector2i(2, 0)
    w.mechanics.append(lever)
    w.mechanics.append(door)
    assert_eq(MechanicOrderValidator.validate(path, w.mechanics), [])
    var lr := Exporter.export_level(w)
    var ls := LevelSystem.new()
    ls.load(lr)
    ls.path_state.move(Vector2i(1, 0))
    assert_true(ls.path_state.move(Vector2i(2, 0)))
    assert_true(ls.check_win())
