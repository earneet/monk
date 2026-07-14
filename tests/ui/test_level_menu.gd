extends GutTest

func _prog(chapters: Array, completed: Array = []) -> LevelProgression:
    return LevelProgression.new(chapters, completed)

func _chapter(cid: String, level_ids: Array) -> ChapterResource:
    var ch := ChapterResource.new()
    ch.id = cid
    ch.display_name = cid
    for lid in level_ids:
        var lr := LevelResource.new()
        lr.meta = LevelMeta.new()
        lr.meta.id = lid
        lr.meta.display_name = lid
        ch.main_levels.append(lr)
    return ch

func _entries(level_ids: Array) -> Array:
    var out: Array = []
    for i in range(level_ids.size()):
        var e := LevelMapEntry.new()
        e.level_id = level_ids[i]
        e.position = Vector2(i * 60, i * 60)
        out.append(e)
    return out

func test_chapter_path_builds_one_node_per_level():
    var view := ChapterPathView.new()
    add_child_autofree(view)
    var ch := _chapter("ch1", ["1-1", "1-2", "1-3"])
    view.build(_entries(["1-1", "1-2", "1-3"]), ch, _prog([ch]), Color.GREEN)
    var level_panels := view.get_children().filter(func(c): return c.is_in_group("level_node"))
    assert_eq(level_panels.size(), 3)

func test_chapter_path_emits_level_selected():
    var view := ChapterPathView.new()
    add_child_autofree(view)
    var ch := _chapter("ch1", ["1-1", "1-2"])
    view.build(_entries(["1-1", "1-2"]), ch, _prog([ch]), Color.GREEN)
    var captured: Array = []
    view.level_selected.connect(func(l): captured.append(l))
    view.select_level(0)
    assert_eq(captured.size(), 1)
    assert_eq((captured[0] as LevelResource).meta.id, "1-1")

func test_chapter_path_emits_back():
    var view := ChapterPathView.new()
    add_child_autofree(view)
    var ch := _chapter("ch1", ["1-1"])
    view.build(_entries(["1-1"]), ch, _prog([ch]), Color.GREEN)
    var emitted := [false]
    view.back_to_world.connect(func(): emitted[0] = true)
    view.request_back()
    assert_true(emitted[0])
