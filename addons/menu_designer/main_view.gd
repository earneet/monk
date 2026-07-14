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

func _refresh_mode_option() -> void:
    _mode_option.clear()
    _mode_option.add_item("世界地图")
    for entry in _layout.chapters:
        var ce := entry as ChapterMapEntry
        var ch := _find_chapter(ce.chapter_id)
        _mode_option.add_item("章节: %s" % (ch.display_name if ch != null else ce.chapter_id))

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
    var errors := _layout.validate(_chapters)
    if errors.size() > 0:
        print("[MenuDesigner] 校验失败,不保存: ", errors)
        return
    var err := ResourceSaver.save(_layout, LAYOUT_PATH)
    if err == OK:
        print("[MenuDesigner] 已保存: ", LAYOUT_PATH)
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

func _add_island() -> void:
    for ch in _chapters:
        var cid: String = (ch as ChapterResource).id
        if not _has_entry(cid):
            var entry := ChapterMapEntry.new()
            entry.chapter_id = cid
            entry.position = Vector2(200, 200 + _layout.chapters.size() * 120)
            entry.theme_color = Color(0.42, 0.56, 0.35)
            entry.icon = "🏯"
            entry.path_size = Vector2(1152, 648)
            _layout.chapters.append(entry)
            print("[MenuDesigner] 添加岛屿: ", cid)
            return
    print("[MenuDesigner] 无可添加章节(所有章节已布局)")

func _add_level(chapter_index: int) -> void:
    var ce := _layout.chapters[chapter_index] as ChapterMapEntry
    var ch := _find_chapter(ce.chapter_id)
    if ch == null:
        return
    for lvl in ch.main_levels:
        var lid: String = (lvl as LevelResource).meta.id
        if not _has_level_entry(ce, lid):
            var entry := LevelMapEntry.new()
            entry.level_id = lid
            entry.position = Vector2(200, 100 + ce.levels.size() * 100)
            ce.levels.append(entry)
            print("[MenuDesigner] 添加关卡: ", lid)
            return
    print("[MenuDesigner] 无可添加关卡(该章节所有关卡已布局)")

func _has_entry(cid: String) -> bool:
    for e in _layout.chapters:
        if (e as ChapterMapEntry).chapter_id == cid:
            return true
    return false

func _has_level_entry(ce: ChapterMapEntry, lid: String) -> bool:
    for le in ce.levels:
        if (le as LevelMapEntry).level_id == lid:
            return true
    return false
