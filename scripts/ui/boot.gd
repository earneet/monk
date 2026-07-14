class_name Boot
extends Control

const LevelScene := preload("res://Scenes/level.tscn")
const LevelMenuScene := preload("res://Scenes/level_menu.tscn")

@export var chapter_paths: Array[String] = [
    "res://resources/chapters/chapter_01.tres",
    "res://resources/chapters/chapter_02.tres",
]
@export var layout_path: String = "res://resources/menu/world_map_layout.tres"

var _chapters: Array[ChapterResource] = []
var _progression: LevelProgression
var _level_menu: LevelMenu
var _level_instance: Node

func _ready() -> void:
    _load_chapters()
    var layout := _load_layout()
    _progression = LevelProgression.new(_chapters, [], _build_next_map(layout))
    _build_menu(layout)

func _load_chapters() -> void:
    _chapters = []
    for path in chapter_paths:
        if ResourceLoader.exists(path):
            var ch := load(path) as ChapterResource
            if ch != null:
                _chapters.append(ch)

func _load_layout() -> WorldMapLayout:
    if ResourceLoader.exists(layout_path):
        return load(layout_path) as WorldMapLayout
    return null

func _build_next_map(layout: WorldMapLayout) -> Dictionary:
    var next_map := {}
    if layout == null:
        return next_map
    for ch_entry in layout.chapters:
        var ce: ChapterMapEntry = ch_entry as ChapterMapEntry
        for le in ce.levels:
            var lme: LevelMapEntry = le as LevelMapEntry
            if lme.next_ids.size() > 0:
                next_map[lme.level_id] = lme.next_ids
    return next_map

func _build_menu(layout: WorldMapLayout) -> void:
    if layout == null:
        return
    _level_menu = LevelMenuScene.instantiate()
    add_child(_level_menu)
    _level_menu.setup(_chapters, layout, _progression)
    _level_menu.level_chosen.connect(_on_level_chosen)

func _on_level_chosen(level: LevelResource) -> void:
    if _level_menu != null:
        _level_menu.visible = false
    _level_instance = LevelScene.instantiate()
    _level_instance.level = level
    _level_instance.won.connect(_on_level_won)
    _level_instance.back_requested.connect(_on_level_back)
    add_child(_level_instance)

func _on_level_won() -> void:
    var id: String = (_level_instance.level as LevelResource).meta.id
    _progression.mark_completed(id)
    _exit_level()
    if _level_menu != null:
        _level_menu.visible = true
        _level_menu.refresh()

func _on_level_back() -> void:
    _exit_level()
    if _level_menu != null:
        _level_menu.visible = true

func _exit_level() -> void:
    if _level_instance != null:
        _level_instance.queue_free()
        _level_instance = null
