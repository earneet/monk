extends Node

const SHOT_DIR := "res://.zcode/shots"
const StageScene := preload("res://tests/visual/temple_stage.tscn")

func _ready() -> void:
    get_window().size = Vector2i(1280, 1170)
    var stage: Node2D = StageScene.instantiate()
    add_child(stage)
    stage.position = Vector2(-418, -27)
    await RenderingServer.frame_post_draw
    var dir := ProjectSettings.globalize_path(SHOT_DIR)
    DirAccess.make_dir_recursive_absolute(dir)
    get_viewport().get_texture().get_image().save_png(dir.path_join("tileset_stage.png"))
    print("[shot] tileset_stage")
    get_tree().quit()
