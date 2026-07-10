extends GutTest

func _ms_with(coord: Vector2i, data: MechanicData) -> MechanicSystem:
    var ms := MechanicSystem.new()
    ms.set_data(coord, data)
    return ms

func test_lever_passable():
    var lever := LeverData.new()
    lever.id = "L1"
    var ms := _ms_with(Vector2i(0, 0), lever)
    assert_true(ms.can_pass(Vector2i(0, 0), []))

func test_lever_pressed_when_coord_in_path():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    assert_true(ms.is_lever_pressed(["L1"], [Vector2i(0, 0)]))

func test_lever_not_pressed_when_coord_absent():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    assert_false(ms.is_lever_pressed(["L1"], [Vector2i(1, 1)]))

func test_lever_unknown_id_treated_as_not_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    assert_false(ms.is_lever_pressed(["NOPE"], [Vector2i(0, 0)]))
