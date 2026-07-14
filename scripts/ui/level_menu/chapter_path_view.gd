class_name ChapterPathView
extends Control

signal level_selected(level: LevelResource)
signal back_to_world()

var _back_button: Button
var _theme_color: Color = Color.GREEN
var _positions: Array[Vector2] = []
var _entries: Array = []
var _id_to_pos: Dictionary = {}
var _chapter: ChapterResource
var _entry_count: int = 0

func build(entries: Array, chapter: ChapterResource, progression: LevelProgression, theme_color: Color) -> void:
    for c in get_children():
        c.queue_free()
    _chapter = chapter
    _entry_count = entries.size()
    _theme_color = theme_color
    _positions.clear()
    _entries = entries
    _id_to_pos.clear()
    var unlocked := progression.unlocked_ids()
    var highlighted := progression.highlighted_id()
    _back_button = Button.new()
    _back_button.text = "◀ 返回世界"
    _back_button.position = Vector2(10, 10)
    _back_button.pressed.connect(request_back)
    add_child(_back_button)
    for i in range(entries.size()):
        var entry: LevelMapEntry = entries[i] as LevelMapEntry
        var is_unlocked: bool = entry.level_id in unlocked
        add_child(_make_node(entry, is_unlocked, entry.level_id == highlighted, progression.is_completed(entry.level_id), i))
        _positions.append(entry.position)
        _id_to_pos[entry.level_id] = entry.position
    queue_redraw()

func select_level(index: int) -> void:
    if _chapter == null or index >= _chapter.main_levels.size():
        return
    level_selected.emit(_chapter.main_levels[index] as LevelResource)

func request_back() -> void:
    back_to_world.emit()

func _make_node(entry: LevelMapEntry, unlocked: bool, highlighted: bool, completed: bool, index: int) -> Panel:
    var panel := Panel.new()
    panel.add_to_group("level_node")
    panel.position = entry.position
    panel.size = Vector2(48, 48)
    var lbl := Label.new()
    var txt: String = ("%d✓" % (index + 1)) if completed else ("%d" % (index + 1))
    if highlighted:
        txt = "▶" + txt
    if not unlocked:
        txt = "🔒"
    lbl.text = txt
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.size = Vector2(48, 48)
    panel.add_child(lbl)
    panel.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.4)
    if unlocked:
        var idx := index
        panel.gui_input.connect(func(ev: InputEvent) -> void:
            if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                select_level(idx))
    return panel

func _draw() -> void:
    for i in range(_entries.size()):
        var from: LevelMapEntry = _entries[i] as LevelMapEntry
        var targets: Array[String] = from.next_ids if from.next_ids.size() > 0 else _default_next_level(i)
        for tid in targets:
            if _id_to_pos.has(tid):
                draw_dashed_line(from.position + Vector2(24, 24), (_id_to_pos[tid] as Vector2) + Vector2(24, 24), _theme_color, 2.0, 6.0)

func _default_next_level(i: int) -> Array[String]:
    if i + 1 < _entries.size():
        return [(_entries[i + 1] as LevelMapEntry).level_id]
    return []
