extends GutTest

func test_empty_path_valid():
    var p: Array[Vector2i] = []
    assert_eq(PathValidator.validate(p, Vector2i(3, 3)), [])

func test_single_cell_valid():
    var p: Array[Vector2i] = [Vector2i(0, 0)]
    assert_eq(PathValidator.validate(p, Vector2i(3, 3)), [])

func test_adjacent_path_valid():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    assert_eq(PathValidator.validate(p, Vector2i(3, 1)), [])

func test_diagonal_rejected():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
    var errs := PathValidator.validate(p, Vector2i(3, 3))
    assert_true(errs.any(func(e: String): return e.find("邻接") >= 0))

func test_duplicate_rejected():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 0)]
    var errs := PathValidator.validate(p, Vector2i(3, 3))
    assert_true(errs.any(func(e: String): return e.find("重复") >= 0))

func test_out_of_bounds_rejected():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 5)]
    var errs := PathValidator.validate(p, Vector2i(3, 3))
    assert_true(errs.any(func(e: String): return e.find("越出") >= 0))
