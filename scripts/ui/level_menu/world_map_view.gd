class_name WorldMapView
extends Control

signal chapter_selected(chapter_id: String, anchor: Vector2)

var _scroll: ScrollContainer
var _content: Control
var _entries: Array = []
var _chapters: Array = []
var _chapter_id_to_pos: Dictionary = {}

func build(layout: WorldMapLayout, chapters: Array, progression: LevelProgression) -> void:
    for c in get_children():
        c.queue_free()
    _entries = layout.chapters
    _chapters = chapters
    _chapter_id_to_pos.clear()
    _scroll = ScrollContainer.new()
    _scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_scroll)
    _content = Control.new()
    _content.size = layout.canvas_size
    _content.custom_minimum_size = layout.canvas_size
    _scroll.add_child(_content)
    var unlocked := progression.unlocked_ids()
    var highlighted := progression.highlighted_id()
    for i in range(layout.chapters.size()):
        var entry: ChapterMapEntry = layout.chapters[i] as ChapterMapEntry
        var ch: ChapterResource = _find_chapter(entry.chapter_id)
        var first_unlocked: bool = ch != null and ch.main_levels.size() > 0 and (ch.main_levels[0] as LevelResource).meta.id in unlocked
        var ch_highlighted: bool = ch != null and highlighted != "" and _chapter_has(ch, highlighted)
        _content.add_child(_make_island(entry, ch, first_unlocked, ch_highlighted))
        _chapter_id_to_pos[entry.chapter_id] = entry.position
    var vsb := _scroll.get_v_scroll_bar()
    var hsb := _scroll.get_h_scroll_bar()
    if not vsb.value_changed.is_connected(_on_scroll_changed):
        vsb.value_changed.connect(_on_scroll_changed)
    if not hsb.value_changed.is_connected(_on_scroll_changed):
        hsb.value_changed.connect(_on_scroll_changed)
    queue_redraw()

func select_island(index: int) -> void:
    if index < 0 or index >= _entries.size():
        return
    var entry: ChapterMapEntry = _entries[index] as ChapterMapEntry
    chapter_selected.emit(entry.chapter_id, entry.position)

func _find_chapter(cid: String) -> ChapterResource:
    for ch in _chapters:
        if (ch as ChapterResource).id == cid:
            return ch
    return null

func _chapter_has(ch: ChapterResource, level_id: String) -> bool:
    for lvl in ch.main_levels:
        if (lvl as LevelResource).meta.id == level_id:
            return true
    return false

func _make_island(entry: ChapterMapEntry, ch: ChapterResource, unlocked: bool, highlighted: bool) -> Control:
    var island := Panel.new()
    island.add_to_group("island_node")
    island.position = entry.position - Vector2(60, 40)
    island.size = Vector2(120, 80)
    island.add_theme_stylebox_override("panel", UITheme.paper_panel(14))
    var lname := Label.new()
    lname.text = entry.icon + " " + (ch.display_name if ch != null else entry.chapter_id)
    lname.position = Vector2(6, 6)
    lname.add_theme_color_override("font_color", UITheme.INK)
    island.add_child(lname)
    if not unlocked:
        var lock := Label.new()
        lock.text = "🔒"
        lock.position = Vector2(45, 40)
        island.add_child(lock)
    island.modulate = Color.WHITE if unlocked else Color(0.82, 0.8, 0.78, 0.92)
    if highlighted:
        island.modulate = Color(1.15, 1.15, 1.15)
    if unlocked:
        var cid: String = entry.chapter_id
        var anchor: Vector2 = entry.position
        island.gui_input.connect(func(ev: InputEvent) -> void:
            if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                chapter_selected.emit(cid, anchor))
    return island

func _on_scroll_changed() -> void:
    queue_redraw()

func _draw() -> void:
    if _scroll == null:
        return
    var offset := Vector2(-_scroll.scroll_horizontal, -_scroll.scroll_vertical)
    for i in range(_entries.size()):
        var from: ChapterMapEntry = _entries[i] as ChapterMapEntry
        var targets: Array[String] = from.next_ids if from.next_ids.size() > 0 else _default_next_chapter(i)
        for tid in targets:
            if _chapter_id_to_pos.has(tid):
                draw_dashed_line(from.position + offset, (_chapter_id_to_pos[tid] as Vector2) + offset, UITheme.INK_SOFT, 3.0, 9.0)

func _default_next_chapter(i: int) -> Array[String]:
    if i + 1 < _entries.size():
        return [(_entries[i + 1] as ChapterMapEntry).chapter_id]
    return []
