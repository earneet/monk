@tool
class_name MenuDesignerMainView
extends Control

const LAYOUT_PATH := "res://resources/menu/world_map_layout.tres"
const CHAPTERS_DIR := "res://resources/chapters"

var _layout: WorldMapLayout
var _chapters: Array = []
var _canvas: MenuCanvas
var _mode_option: OptionButton

func _ready() -> void:
    _build_ui()
    _load_all()

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(vbox)
    var toolbar := HBoxContainer.new()
    vbox.add_child(toolbar)
    var load_btn := Button.new()
    load_btn.text = "加载"
    load_btn.pressed.connect(_load_all)
    toolbar.add_child(load_btn)
    var save_btn := Button.new()
    save_btn.text = "保存"
    save_btn.pressed.connect(_on_save)
    toolbar.add_child(save_btn)
    var add_btn := Button.new()
    add_btn.text = "添加节点"
    add_btn.pressed.connect(_on_add_node)
    toolbar.add_child(add_btn)
    var del_btn := Button.new()
    del_btn.text = "删除末节点"
    del_btn.pressed.connect(_on_delete_node)
    toolbar.add_child(del_btn)
    var clear_btn := Button.new()
    clear_btn.text = "清空当前模式"
    clear_btn.pressed.connect(_on_clear_mode)
    toolbar.add_child(clear_btn)
    _mode_option = OptionButton.new()
    _mode_option.item_selected.connect(_on_mode_changed)
    toolbar.add_child(_mode_option)
    _canvas = MenuCanvas.new()
    _canvas.custom_minimum_size = Vector2(800, 500)
    _canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(_canvas)

func _load_all() -> void:
    _chapters = _load_chapters()
    if ResourceLoader.exists(LAYOUT_PATH):
        _layout = load(LAYOUT_PATH) as WorldMapLayout
    else:
        _layout = WorldMapLayout.new()
        _layout.canvas_size = Vector2(1152, 648)
    _materialize_defaults()
    _refresh_mode_option()
    _apply_canvas()

func _load_chapters() -> Array:
    var result: Array = []
    var dir := DirAccess.open(CHAPTERS_DIR)
    if dir == null:
        return result
    dir.list_dir_begin()
    var fn := dir.get_next()
    while fn != "":
        if fn.ends_with(".tres"):
            var ch := load("%s/%s" % [CHAPTERS_DIR, fn]) as ChapterResource
            if ch != null:
                result.append(ch)
        fn = dir.get_next()
    return result

func _materialize_defaults() -> void:
    if _layout == null:
        return
    for i in range(_layout.chapters.size()):
        var ce := _layout.chapters[i] as ChapterMapEntry
        if ce.next_ids.is_empty() and i + 1 < _layout.chapters.size():
            ce.next_ids = [(_layout.chapters[i + 1] as ChapterMapEntry).chapter_id]
        for j in range(ce.levels.size()):
            var le := ce.levels[j] as LevelMapEntry
            if le.next_ids.is_empty() and j + 1 < ce.levels.size():
                le.next_ids = [(ce.levels[j + 1] as LevelMapEntry).level_id]

func _refresh_mode_option() -> void:
    var prev := _mode_option.selected
    _mode_option.clear()
    _mode_option.add_item("世界地图")
    for entry in _layout.chapters:
        var ce := entry as ChapterMapEntry
        var ch := _find_chapter(ce.chapter_id)
        _mode_option.add_item("章节: %s" % (ch.display_name if ch != null else ce.chapter_id))
    var target := prev if prev > 0 else 0
    if target >= _mode_option.item_count:
        target = _mode_option.item_count - 1
    _mode_option.selected = target

func _find_chapter(cid: String) -> ChapterResource:
    for ch in _chapters:
        if (ch as ChapterResource).id == cid:
            return ch
    return null

func _on_mode_changed(_idx: int) -> void:
    _apply_canvas()

func _apply_canvas() -> void:
    var idx := _mode_option.selected
    if idx <= 0:
        _canvas.build(_layout, _chapters, "world", 0)
    else:
        _canvas.build(_layout, _chapters, "chapter", idx - 1)

func _on_save() -> void:
    if _layout == null:
        return
    var clean := _strip_placeholders()
    var errors := clean.validate(_chapters)
    if errors.size() > 0:
        print("[MenuDesigner] 校验失败,不保存: ", errors)
        return
    var err := ResourceSaver.save(clean, LAYOUT_PATH)
    if err == OK:
        print("[MenuDesigner] 已保存(过滤未关联节点): ", LAYOUT_PATH)
    else:
        print("[MenuDesigner] 保存失败: ", err)

func _on_add_node() -> void:
    if _layout == null:
        return
    if _mode_option.selected <= 0:
        _add_island()
    else:
        _add_level(_mode_option.selected - 1)
    _refresh_mode_option()
    _apply_canvas()

func _on_delete_node() -> void:
    if _layout == null or _mode_option.selected < 0:
        return
    if _mode_option.selected <= 0:
        if _layout.chapters.size() > 0:
            _layout.chapters.remove_at(_layout.chapters.size() - 1)
    else:
        var ce := _layout.chapters[_mode_option.selected - 1] as ChapterMapEntry
        if ce.levels.size() > 0:
            ce.levels.remove_at(ce.levels.size() - 1)
    _refresh_mode_option()
    _apply_canvas()

func _on_clear_mode() -> void:
    if _layout == null:
        return
    if _mode_option.selected <= 0:
        _layout.chapters.clear()
    elif _mode_option.selected - 1 < _layout.chapters.size():
        (_layout.chapters[_mode_option.selected - 1] as ChapterMapEntry).levels.clear()
    _refresh_mode_option()
    _apply_canvas()

func _add_island() -> void:
    var entry := ChapterMapEntry.new()
    entry.chapter_id = "node_%d" % (_layout.chapters.size() + 1)
    entry.position = Vector2(200, 200 + _layout.chapters.size() * 120)
    entry.theme_color = Color(0.5, 0.5, 0.5)
    entry.icon = "❓"
    entry.path_size = Vector2(1152, 648)
    _layout.chapters.append(entry)

func _add_level(chapter_index: int) -> void:
    var ce := _layout.chapters[chapter_index] as ChapterMapEntry
    var entry := LevelMapEntry.new()
    entry.level_id = "node_%d" % (ce.levels.size() + 1)
    entry.position = Vector2(200, 100 + ce.levels.size() * 100)
    ce.levels.append(entry)

func _real_chapter_ids() -> Dictionary:
    var d := {}
    for ch in _chapters:
        d[(ch as ChapterResource).id] = true
    return d

func _real_level_ids() -> Dictionary:
    var d := {}
    for ch in _chapters:
        for lvl in (ch as ChapterResource).main_levels:
            d[(lvl as LevelResource).meta.id] = true
    return d

func _strip_placeholders() -> WorldMapLayout:
    var clean := WorldMapLayout.new()
    clean.canvas_size = _layout.canvas_size
    var real_ch := _real_chapter_ids()
    var real_lvl := _real_level_ids()
    for entry in _layout.chapters:
        var ce := entry as ChapterMapEntry
        if not real_ch.has(ce.chapter_id):
            continue
        var copy := ChapterMapEntry.new()
        copy.chapter_id = ce.chapter_id
        copy.position = ce.position
        copy.theme_color = ce.theme_color
        copy.icon = ce.icon
        copy.path_size = ce.path_size
        for nid in ce.next_ids:
            if real_ch.has(nid):
                copy.next_ids.append(nid)
        for le in ce.levels:
            var lme := le as LevelMapEntry
            if not real_lvl.has(lme.level_id):
                continue
            var lcopy := LevelMapEntry.new()
            lcopy.level_id = lme.level_id
            lcopy.position = lme.position
            for nid in lme.next_ids:
                if real_lvl.has(nid):
                    lcopy.next_ids.append(nid)
            copy.levels.append(lcopy)
        clean.chapters.append(copy)
    return clean
