extends GutTest

const SaveSystemScript := preload("res://scripts/level/save_system.gd")

const _TMP_NAME := "tmp_test_boot_progress.json"

var _original_save_path := ""

func _save_system() -> SaveSystemScript:
    return get_node(SaveSystemScript.AUTOLOAD_PATH) as SaveSystemScript

func before_each() -> void:
    _original_save_path = _save_system().save_path
    _save_system().save_path = "user://" + _TMP_NAME
    _delete_tmp()

func after_each() -> void:
    _delete_tmp()
    _save_system().save_path = _original_save_path

func _delete_tmp() -> void:
    var dir := DirAccess.open("user://")
    if dir != null:
        if dir.file_exists(_TMP_NAME):
            dir.remove(_TMP_NAME)
        if dir.file_exists(_TMP_NAME + ".tmp"):
            dir.remove(_TMP_NAME + ".tmp")

func _write_raw(text: String) -> void:
    var f := FileAccess.open("user://" + _TMP_NAME, FileAccess.WRITE)
    if f == null:
        fail_test("测试夹具失败:无法写临时存档 user://" + _TMP_NAME)
        return
    f.store_string(text)
    f.close()

func _flat_level(id: String) -> LevelResource:
    var lr := LevelResource.new()
    lr.size = Vector2i(2, 1)
    lr.tiles.clear()
    var row: Array[int] = []
    row.append(LevelResource.TileType.EMPTY)
    row.append(LevelResource.TileType.EMPTY)
    lr.tiles.append(row)
    lr.start = Vector2i(0, 0)
    lr.goal = Vector2i(-1, -1)
    lr.meta = LevelMeta.new()
    lr.meta.id = id
    return lr

class StubLevelHolder extends Node:
    var level: LevelResource

func test_ready_safe_without_chapter_files():
    var boot := Boot.new()
    boot.chapter_paths = ["res://resources/chapters/__nonexistent__.tres"]
    boot.layout_path = "res://resources/menu/__nonexistent__.tres"
    add_child_autofree(boot)
    assert_not_null(boot._progression)
    assert_eq(boot._chapters.size(), 0)

func test_level_instance_cleaned_on_exit():
    var boot := Boot.new()
    add_child_autofree(boot)
    boot._exit_level()
    assert_true(boot._level_instance == null)

func test_ready_hydrates_progress_from_save():
    _save_system().save_completed(["1-1"])
    var boot := Boot.new()
    add_child_autofree(boot)
    assert_true(boot._progression.is_completed("1-1"))
    assert_false(boot._progression.is_completed("1-2"))
    assert_true("1-2" in boot._progression.unlocked_ids())

func test_ready_with_corrupt_save_degrades_to_empty():
    _write_raw("{{{ broken")
    var boot := Boot.new()
    add_child_autofree(boot)
    assert_not_null(boot._progression)
    assert_false(boot._progression.is_completed("1-1"))
    assert_engine_error_count(1, "坏 JSON 触发引擎解析错误")
    assert_push_warning("存档损坏")

func test_level_won_persists_completed():
    var boot := Boot.new()
    add_child_autofree(boot)
    var holder := StubLevelHolder.new()
    var lr := LevelResource.new()
    lr.meta = LevelMeta.new()
    lr.meta.id = "1-1"
    holder.level = lr
    add_child_autoqfree(holder)
    boot._level_instance = holder
    boot._on_level_won()
    assert_true(boot._progression.is_completed("1-1"))
    assert_true(boot._level_instance == null)
    assert_true(boot._level_menu.visible == true)
    assert_eq(_save_system().load_completed(), ["1-1"])

func test_level_chosen_won_signal_persists_and_restores_menu():
    var boot := Boot.new()
    add_child_autofree(boot)
    boot._on_level_chosen(_flat_level("1-1"))
    assert_true(boot._level_menu.visible == false)
    assert_true(boot._level_instance != null)
    boot._level_instance.won.emit()
    assert_true(boot._level_instance == null)
    assert_true(boot._level_menu.visible == true)
    assert_eq(_save_system().load_completed(), ["1-1"])
