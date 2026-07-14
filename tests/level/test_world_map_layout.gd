extends GutTest

func test_level_map_entry_defaults():
    var e := LevelMapEntry.new()
    assert_eq(e.level_id, "")
    assert_eq(e.position, Vector2.ZERO)

func test_chapter_map_entry_defaults():
    var e := ChapterMapEntry.new()
    assert_eq(e.chapter_id, "")
    assert_eq(e.position, Vector2.ZERO)
    assert_eq(e.theme_color, Color.BLACK)
    assert_eq(e.icon, "")
    assert_eq(e.path_size, Vector2.ZERO)
    assert_eq(e.levels.size(), 0)

func test_layout_defaults_and_nest():
    var layout := WorldMapLayout.new()
    assert_eq(layout.canvas_size, Vector2.ZERO)
    assert_eq(layout.chapters.size(), 0)
    var ch := ChapterMapEntry.new()
    ch.chapter_id = "ch1"
    ch.position = Vector2(10, 20)
    var lvl := LevelMapEntry.new()
    lvl.level_id = "1-1"
    lvl.position = Vector2(5, 5)
    ch.levels = [lvl]
    layout.chapters = [ch]
    assert_eq(layout.chapters.size(), 1)
    assert_eq((layout.chapters[0] as ChapterMapEntry).levels.size(), 1)

func _level_res(id: String) -> LevelResource:
    var lr := LevelResource.new()
    lr.meta = LevelMeta.new()
    lr.meta.id = id
    return lr

func _chapter_res(cid: String, level_ids: Array) -> ChapterResource:
    var ch := ChapterResource.new()
    ch.id = cid
    for lid in level_ids:
        ch.main_levels.append(_level_res(lid))
    return ch

func _entry(cid: String, level_ids: Array) -> ChapterMapEntry:
    var e := ChapterMapEntry.new()
    e.chapter_id = cid
    for lid in level_ids:
        var le := LevelMapEntry.new()
        le.level_id = lid
        e.levels.append(le)
    return e

func test_validate_ok_returns_empty():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("ch1", ["1-1", "1-2"]), _entry("ch2", ["2-1"])]
    var chapters := [_chapter_res("ch1", ["1-1", "1-2"]), _chapter_res("ch2", ["2-1"])]
    assert_eq(layout.validate(chapters), [])

func test_validate_missing_level_position():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("ch1", ["1-1"])]
    var chapters := [_chapter_res("ch1", ["1-1", "1-2"])]
    var errors := layout.validate(chapters)
    assert_true(errors.any(func(e): return e.find("1-2") >= 0))

func test_validate_unknown_chapter_id():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("chX", ["1-1"])]
    var chapters := [_chapter_res("ch1", ["1-1"])]
    var errors := layout.validate(chapters)
    assert_true(errors.any(func(e): return e.find("chX") >= 0 or e.find("ch1") >= 0))

func test_validate_wrong_order():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("ch1", ["1-2", "1-1"])]
    var chapters := [_chapter_res("ch1", ["1-1", "1-2"])]
    var errors := layout.validate(chapters)
    assert_true(errors.any(func(e): return e.find("顺序") >= 0))
