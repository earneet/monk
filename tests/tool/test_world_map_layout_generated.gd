extends GutTest

const LAYOUT_PATH := "res://resources/menu/world_map_layout.tres"

func test_layout_exists_and_validates():
    assert_true(ResourceLoader.exists(LAYOUT_PATH), "world_map_layout.tres 未生成")
    var layout := load(LAYOUT_PATH) as WorldMapLayout
    assert_not_null(layout)
    var ch1 := load("res://resources/chapters/chapter_01.tres") as ChapterResource
    var ch2 := load("res://resources/chapters/chapter_02.tres") as ChapterResource
    assert_eq(layout.validate([ch1, ch2]), [])

func test_layout_has_two_chapters_and_counts():
    var layout := load(LAYOUT_PATH) as WorldMapLayout
    assert_eq(layout.chapters.size(), 2)
    assert_eq((layout.chapters[0] as ChapterMapEntry).levels.size(), 5)
    assert_eq((layout.chapters[1] as ChapterMapEntry).levels.size(), 3)

func test_level_ids_match_actual_meta():
    var layout := load(LAYOUT_PATH) as WorldMapLayout
    for ci in range(layout.chapters.size()):
        var entry := layout.chapters[ci] as ChapterMapEntry
        var path := "res://resources/chapters/chapter_0%d.tres" % (ci + 1)
        var ch := load(path) as ChapterResource
        for i in range(entry.levels.size()):
            var lid: String = (entry.levels[i] as LevelMapEntry).level_id
            var mid: String = (ch.main_levels[i] as LevelResource).meta.id
            assert_eq(lid, mid)
