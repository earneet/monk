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

func _layout(chapters: Array) -> WorldMapLayout:
    var layout := WorldMapLayout.new()
    layout.canvas_size = Vector2(400, 800)
    var entries: Array[ChapterMapEntry] = []
    var i := 0
    for ch in chapters:
        var ce := ChapterMapEntry.new()
        ce.chapter_id = (ch as ChapterResource).id
        ce.position = Vector2(200, 150 + i * 250)
        ce.theme_color = Color.GREEN
        ce.icon = "🏯"
        ce.path_size = Vector2(400, 600)
        for lvl in (ch as ChapterResource).main_levels:
            var le := LevelMapEntry.new()
            le.level_id = (lvl as LevelResource).meta.id
            le.position = Vector2(50, 50)
            ce.levels.append(le)
        entries.append(ce)
        i += 1
    layout.chapters = entries
    return layout

func test_world_map_builds_one_island_per_chapter():
    var view := WorldMapView.new()
    add_child_autofree(view)
    var ch1 := _chapter("ch1", ["1-1"])
    var ch2 := _chapter("ch2", ["2-1"])
    var layout := _layout([ch1, ch2])
    view.build(layout, [ch1, ch2], _prog([ch1, ch2]))
    var islands := view.find_children("*", "Panel", true, false)
    assert_eq(islands.size(), 2)

func test_world_map_emits_chapter_selected():
    var view := WorldMapView.new()
    add_child_autofree(view)
    var ch1 := _chapter("ch1", ["1-1"])
    var ch2 := _chapter("ch2", ["2-1"])
    var layout := _layout([ch1, ch2])
    view.build(layout, [ch1, ch2], _prog([ch1, ch2]))
    var captured_id := [""]
    view.chapter_selected.connect(func(cid, anchor): captured_id[0] = cid)
    view.select_island(1)
    assert_eq(captured_id[0], "ch2")

func test_menu_setup_builds_world():
    var menu := LevelMenu.new()
    add_child_autofree(menu)
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var layout := _layout([ch1])
    menu.setup([ch1], layout, _prog([ch1]))
    assert_eq(menu.current_state(), LevelMenu.State.WORLD)

func test_menu_enter_chapter_then_choose_level():
    var menu := LevelMenu.new()
    add_child_autofree(menu)
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var layout := _layout([ch1])
    menu.setup([ch1], layout, _prog([ch1]))
    menu.enter_chapter("ch1", Vector2(200, 150))
    assert_eq(menu.current_state(), LevelMenu.State.CHAPTER)
    var captured: Array = []
    menu.level_chosen.connect(func(l): captured.append(l))
    menu.choose_level("1-1")
    assert_eq(captured.size(), 1)

func test_menu_back_to_world():
    var menu := LevelMenu.new()
    add_child_autofree(menu)
    var ch1 := _chapter("ch1", ["1-1"])
    var layout := _layout([ch1])
    menu.setup([ch1], layout, _prog([ch1]))
    menu.enter_chapter("ch1", Vector2(200, 150))
    menu.back_to_world_requested()
    assert_eq(menu.current_state(), LevelMenu.State.WORLD)
