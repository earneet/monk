extends GutTest

func test_fields_default_empty():
    var ch := ChapterResource.new()
    assert_eq(ch.id, "")
    assert_eq(ch.display_name, "")
    assert_eq(ch.main_levels, [])

func test_fields_assigned():
    var ch := ChapterResource.new()
    ch.id = "ch1"
    ch.display_name = "前院"
    var lr := LevelResource.new()
    ch.main_levels.append(lr)
    assert_eq(ch.id, "ch1")
    assert_eq(ch.display_name, "前院")
    assert_eq(ch.main_levels.size(), 1)
    assert_eq(ch.main_levels[0], lr)
