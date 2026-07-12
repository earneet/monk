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
