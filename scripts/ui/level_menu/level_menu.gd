class_name LevelMenu
extends Control

enum State { WORLD, CHAPTER }

const TRANS_TIME := 0.4

signal level_chosen(level: LevelResource)

var _chapters: Array = []
var _layout: WorldMapLayout
var _progression: LevelProgression
var _state: int = State.WORLD
var _current_chapter_id: String = ""
var _world_view: WorldMapView
var _path_view: ChapterPathView

func setup(chapters: Array, layout: WorldMapLayout, progression: LevelProgression) -> void:
    _chapters = chapters
    _layout = layout
    _progression = progression
    _state = State.WORLD
    _ensure_views()
    _world_view.build(layout, chapters, progression)
    _path_view.visible = false
    if not _world_view.chapter_selected.is_connected(_on_chapter_selected):
        _world_view.chapter_selected.connect(_on_chapter_selected)
    if not _path_view.level_selected.is_connected(_on_level_selected):
        _path_view.level_selected.connect(_on_level_selected)
    if not _path_view.back_to_world.is_connected(_on_back_to_world):
        _path_view.back_to_world.connect(_on_back_to_world)

func _ensure_views() -> void:
    if _world_view == null:
        _world_view = WorldMapView.new()
        _world_view.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(_world_view)
    if _path_view == null:
        _path_view = ChapterPathView.new()
        _path_view.set_anchors_preset(Control.PRESET_FULL_RECT)
        _path_view.visible = false
        add_child(_path_view)

func current_state() -> int:
    return _state

func enter_chapter(chapter_id: String, anchor: Vector2) -> void:
    _current_chapter_id = chapter_id
    _state = State.CHAPTER
    var entry := _find_entry(chapter_id)
    var ch := _find_chapter(chapter_id)
    if entry == null or ch == null:
        return
    _path_view.build(entry.levels, ch, _progression, entry.theme_color)
    _play_enter_tween(anchor)

func choose_level(level_id: String) -> void:
    var ch := _find_chapter(_current_chapter_id)
    if ch == null:
        return
    for lvl in ch.main_levels:
        if (lvl as LevelResource).meta.id == level_id:
            level_chosen.emit(lvl as LevelResource)
            return

func back_to_world_requested() -> void:
    _state = State.WORLD
    _play_exit_tween()

func refresh() -> void:
    if _state != State.CHAPTER:
        return
    var entry := _find_entry(_current_chapter_id)
    var ch := _find_chapter(_current_chapter_id)
    if entry != null and ch != null:
        _path_view.build(entry.levels, ch, _progression, entry.theme_color)

func _on_chapter_selected(chapter_id: String, anchor: Vector2) -> void:
    enter_chapter(chapter_id, anchor)

func _on_level_selected(level: LevelResource) -> void:
    level_chosen.emit(level)

func _on_back_to_world() -> void:
    back_to_world_requested()

func _find_entry(cid: String) -> ChapterMapEntry:
    for e in _layout.chapters:
        if (e as ChapterMapEntry).chapter_id == cid:
            return e
    return null

func _find_chapter(cid: String) -> ChapterResource:
    for ch in _chapters:
        if (ch as ChapterResource).id == cid:
            return ch
    return null

func _play_enter_tween(_anchor: Vector2) -> void:
    _path_view.visible = true
    _path_view.modulate.a = 0.0
    _path_view.scale = Vector2(0.3, 0.3)
    var tw := create_tween().set_parallel(true)
    tw.tween_property(_world_view, "modulate:a", 0.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "modulate:a", 1.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "scale", Vector2.ONE, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.chain().tween_callback(func(): _world_view.visible = false)

func _play_exit_tween() -> void:
    _world_view.visible = true
    var tw := create_tween().set_parallel(true)
    tw.tween_property(_world_view, "modulate:a", 1.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "modulate:a", 0.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "scale", Vector2(0.3, 0.3), TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.chain().tween_callback(func(): _path_view.visible = false)
