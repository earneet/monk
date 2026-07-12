extends GutTest

func _level(id: String) -> LevelResource:
    var lr := LevelResource.new()
    lr.meta = LevelMeta.new()
    lr.meta.id = id
    lr.meta.display_name = id
    return lr

func _chapter(ch_id: String, level_ids: Array) -> ChapterResource:
    var ch := ChapterResource.new()
    ch.id = ch_id
    ch.display_name = ch_id
    for lid in level_ids:
        ch.main_levels.append(_level(lid))
    return ch

func test_initial_unlocks_only_first():
    var ch1 := _chapter("ch1", ["1-1", "1-2", "1-3"])
    var prog := LevelProgression.new([ch1])
    assert_eq(prog.unlocked_ids(), ["1-1"])
    assert_eq(prog.highlighted_id(), "1-1")

func test_unlock_next_after_complete():
    var ch1 := _chapter("ch1", ["1-1", "1-2", "1-3"])
    var prog := LevelProgression.new([ch1])
    prog.mark_completed("1-1")
    assert_eq(prog.unlocked_ids(), ["1-1", "1-2"])
    assert_eq(prog.highlighted_id(), "1-2")

func test_unlock_crosses_chapter_boundary():
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var ch2 := _chapter("ch2", ["2-1", "2-2"])
    var prog := LevelProgression.new([ch1, ch2])
    prog.mark_completed("1-1")
    prog.mark_completed("1-2")
    assert_eq(prog.unlocked_ids(), ["1-1", "1-2", "2-1"])
    assert_eq(prog.highlighted_id(), "2-1")

func test_highlighted_empty_when_all_complete():
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var prog := LevelProgression.new([ch1])
    prog.mark_completed("1-1")
    prog.mark_completed("1-2")
    assert_eq(prog.highlighted_id(), "")

func test_completed_from_init_arg():
    var ch1 := _chapter("ch1", ["1-1", "1-2", "1-3"])
    var prog := LevelProgression.new([ch1], ["1-1"])
    assert_eq(prog.unlocked_ids(), ["1-1", "1-2"])
    assert_true(prog.is_completed("1-1"))
    assert_false(prog.is_completed("1-2"))

func test_empty_chapters_safe():
    var prog := LevelProgression.new([])
    assert_eq(prog.unlocked_ids(), [])
    assert_eq(prog.highlighted_id(), "")
