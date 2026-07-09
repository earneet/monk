extends GutTest

func test_neighbors_four_directions():
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    var n := gm.neighbors(Vector2i(1, 1))
    assert_eq(n.size(), 4)
    assert_true(n.has(Vector2i(0, 1)))
    assert_true(n.has(Vector2i(2, 1)))
    assert_true(n.has(Vector2i(1, 0)))
    assert_true(n.has(Vector2i(1, 2)))

func test_neighbors_at_corner_excludes_out_of_bounds():
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    var n := gm.neighbors(Vector2i(0, 0))
    assert_eq(n.size(), 2)

func test_in_bounds():
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    assert_true(gm.in_bounds(Vector2i(2, 2)))
    assert_false(gm.in_bounds(Vector2i(3, 0)))
    assert_false(gm.in_bounds(Vector2i(-1, 0)))
