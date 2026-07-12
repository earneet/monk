extends GutTest

func test_spiral_covers_all_cells():
    var path := PathGenerator.generate_spiral(Vector2i(3, 3))
    assert_eq(path.size(), 9)
    var seen: Dictionary = {}
    for c in path:
        assert_false(seen.has(c))
        seen[c] = true

func test_spiral_starts_origin():
    var path := PathGenerator.generate_spiral(Vector2i(3, 3))
    assert_eq(path[0], Vector2i(0, 0))

func test_spiral_adjacent():
    var path := PathGenerator.generate_spiral(Vector2i(4, 3))
    for i in range(1, path.size()):
        var d: Vector2i = path[i] - path[i - 1]
        assert_eq(abs(d.x) + abs(d.y), 1)

func test_hilbert_power_of_2_covers_all():
    var path := PathGenerator.generate_hilbert(Vector2i(4, 4))
    assert_eq(path.size(), 16)
    var seen: Dictionary = {}
    for c in path:
        assert_false(seen.has(c))
        seen[c] = true

func test_hilbert_adjacent():
    var path := PathGenerator.generate_hilbert(Vector2i(4, 4))
    for i in range(1, path.size()):
        var d: Vector2i = path[i] - path[i - 1]
        assert_eq(abs(d.x) + abs(d.y), 1)

func test_hilbert_non_power_of_2_degrades_to_spiral():
    var h := PathGenerator.generate_hilbert(Vector2i(3, 3))
    var s := PathGenerator.generate_spiral(Vector2i(3, 3))
    assert_eq(h, s)

func test_heuristic_covers_all_cells():
    var path := PathGenerator.generate_heuristic(Vector2i(4, 4))
    assert_eq(path.size(), 16)
    var seen: Dictionary = {}
    for c in path:
        assert_false(seen.has(c))
        seen[c] = true

func test_heuristic_adjacent():
    var path := PathGenerator.generate_heuristic(Vector2i(4, 4))
    for i in range(1, path.size()):
        var d: Vector2i = path[i] - path[i - 1]
        assert_eq(abs(d.x) + abs(d.y), 1)

func test_random_walk_starts_at_start():
    var path := PathGenerator.generate_random_walk(Vector2i(5, 5), Vector2i(1, 1), Vector2i(-1, -1))
    assert_true(path.size() > 0)
    assert_eq(path[0], Vector2i(1, 1))

func test_random_walk_no_repeat_in_bounds_adjacent():
    var path := PathGenerator.generate_random_walk(Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1))
    var seen: Dictionary = {}
    for i in range(path.size()):
        var c: Vector2i = path[i]
        assert_true(c.x >= 0 and c.x < 5 and c.y >= 0 and c.y < 5)
        assert_false(seen.has(c))
        seen[c] = true
        if i > 0:
            var d: Vector2i = path[i] - path[i - 1]
            assert_eq(abs(d.x) + abs(d.y), 1)

func test_random_walk_not_full_coverage():
    var path := PathGenerator.generate_random_walk(Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1))
    assert_true(path.size() < 36)
