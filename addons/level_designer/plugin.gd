@tool
extends EditorPlugin

var main_view: Control

func _enter_tree() -> void:
    main_view = LevelDesignerMainView.new()
    EditorInterface.get_editor_main_screen().add_child(main_view)
    _make_visible(false)

func _exit_tree() -> void:
    if main_view:
        main_view.queue_free()
        main_view = null

func _has_main_screen() -> bool:
    return true

func _make_visible(visible: bool) -> void:
    if main_view:
        main_view.visible = visible

func _get_plugin_name() -> String:
    return "LevelDesigner"

func _get_plugin_icon() -> Texture2D:
    return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
