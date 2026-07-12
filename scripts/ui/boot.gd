class_name Boot
extends Control

const LevelScene := preload("res://Scenes/level.tscn")

@export var chapter_paths: Array[String] = [
    "res://resources/chapters/chapter_01.tres",
    "res://resources/chapters/chapter_02.tres",
]

var _chapters: Array[ChapterResource] = []
var _progression: LevelProgression
var _select_container: VBoxContainer
var _level_instance: Node

func _ready() -> void:
    _load_chapters()
    _progression = LevelProgression.new(_chapters)
    _build_select_ui()

func _load_chapters() -> void:
    _chapters = []
    for path in chapter_paths:
        if ResourceLoader.exists(path):
            var ch := load(path) as ChapterResource
            if ch != null:
                _chapters.append(ch)

func _build_select_ui() -> void:
    for c in get_children():
        c.queue_free()
    _select_container = VBoxContainer.new()
    _select_container.position = Vector2(20, 20)
    _select_container.size = Vector2(400, 600)
    add_child(_select_container)
    var unlocked := _progression.unlocked_ids()
    var highlighted := _progression.highlighted_id()
    for ch in _chapters:
        var title := Label.new()
        title.text = ch.display_name
        _select_container.add_child(title)
        for lvl in ch.main_levels:
            var level: LevelResource = lvl as LevelResource
            var id: String = level.meta.id
            var btn := Button.new()
            btn.text = level.meta.display_name
            if _progression.is_completed(id):
                btn.text = "✓ " + btn.text
            if id == highlighted:
                btn.text = "▶ " + btn.text
            btn.disabled = not (id in unlocked)
            btn.pressed.connect(_on_level_selected.bind(level))
            _select_container.add_child(btn)

func _on_level_selected(level: LevelResource) -> void:
    if _select_container != null:
        _select_container.visible = false
    _level_instance = LevelScene.instantiate()
    _level_instance.level = level
    _level_instance.won.connect(_on_level_won)
    _level_instance.back_requested.connect(_on_level_back)
    add_child(_level_instance)

func _on_level_won() -> void:
    var id: String = (_level_instance.level as LevelResource).meta.id
    _progression.mark_completed(id)
    _exit_level()

func _on_level_back() -> void:
    _exit_level()

func _exit_level() -> void:
    if _level_instance != null:
        _level_instance.queue_free()
        _level_instance = null
    if _select_container != null:
        _build_select_ui()
        _select_container.visible = true
