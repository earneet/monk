extends GutTest

func _ms_with(coord: Vector2i, data: MechanicData) -> MechanicSystem:
    var ms := MechanicSystem.new()
    ms.set_data(coord, data)
    return ms

func test_wall_not_passable():
    var ms := _ms_with(Vector2i(0, 0), WallData.new())
    assert_false(ms.can_pass(Vector2i(0, 0), []))

func test_flowing_water_not_passable():
    var ms := _ms_with(Vector2i(0, 0), FlowingWaterData.new())
    assert_false(ms.can_pass(Vector2i(0, 0), []))

func test_empty_passable():
    var ms := MechanicSystem.new()
    assert_true(ms.can_pass(Vector2i(0, 0), []))

func test_wall_not_counted_for_cover():
    assert_false(WallData.new().counts_for_need_cover())

func test_flowing_water_not_counted_for_cover():
    assert_false(FlowingWaterData.new().counts_for_need_cover())
