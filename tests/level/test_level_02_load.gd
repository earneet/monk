extends GutTest

func test_level_02_loads_and_validates():
    var lr := load("res://resources/levels/test_level_02.tres") as LevelResource
    assert_not_null(lr)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_eq(ls.validate(lr), [])
    var nc := ls.need_cover()
    assert_true(nc.has(Vector2i(1, 0)))
    assert_true(nc.has(Vector2i(3, 0)))
    assert_true(nc.has(Vector2i(4, 2)))
    assert_true(nc.has(Vector2i(2, 4)))
