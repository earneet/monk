extends GutTest

func test_door_closed_when_lever_not_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), door)
    assert_false(ms.can_pass(Vector2i(2, 0), [Vector2i(1, 1)]))

func test_door_open_when_lever_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), door)
    assert_true(ms.can_pass(Vector2i(2, 0), [Vector2i(0, 0)]))

func test_door_or_semantics_any_lever_opens():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    ms.register_lever("L2", Vector2i(5, 5))
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1", "L2"]
    ms.set_data(Vector2i(2, 0), door)
    assert_true(ms.can_pass(Vector2i(2, 0), [Vector2i(5, 5)]))

func test_door_empty_lever_ids_always_closed():
    var ms := MechanicSystem.new()
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = []
    ms.set_data(Vector2i(2, 0), door)
    assert_false(ms.can_pass(Vector2i(2, 0), [Vector2i(0, 0), Vector2i(1, 0)]))
