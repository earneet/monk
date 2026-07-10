extends GutTest

func _ms_with(coord: Vector2i, period: int) -> MechanicSystem:
    var ms := MechanicSystem.new()
    var dw := DynamicWaterData.new()
    dw.coord = coord
    dw.period = period
    ms.set_data(coord, dw)
    return ms

func test_period2_phases():
    var ms := _ms_with(Vector2i(0, 0), 2)
    assert_true(ms.can_pass(Vector2i(0, 0), []))
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9)]))
    assert_true(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8)]))

func test_period4_phases():
    var ms := _ms_with(Vector2i(0, 0), 4)
    assert_true(ms.can_pass(Vector2i(0, 0), []))
    assert_true(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9)]))
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8)]))
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8), Vector2i(9, 7)]))

func test_period3_phases():
    var ms := _ms_with(Vector2i(0, 0), 3)
    assert_true(ms.can_pass(Vector2i(0, 0), []))
    assert_true(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9)]))
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8)]))

func test_default_period_is_4():
    var dw := DynamicWaterData.new()
    assert_eq(dw.period, 4)
