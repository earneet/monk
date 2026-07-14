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
