extends GutTest

const SaveSystemScript := preload("res://scripts/level/save_system.gd")

const _TMP_NAME := "tmp_test_save_system.json"

var _save: SaveSystemScript

func before_each() -> void:
    _save = SaveSystemScript.new()
    autofree(_save)
    _save.save_path = "user://" + _TMP_NAME
    _delete_tmp()

func after_each() -> void:
    _delete_tmp()

func _delete_tmp() -> void:
    var dir := DirAccess.open("user://")
    if dir != null and dir.file_exists(_TMP_NAME):
        dir.remove(_TMP_NAME)

func _write_raw(text: String) -> void:
    var f := FileAccess.open("user://" + _TMP_NAME, FileAccess.WRITE)
    f.store_string(text)
    f.close()

func test_load_missing_file_returns_empty():
    assert_eq(_save.load_completed(), [])

func test_save_then_load_roundtrip():
    var ok := _save.save_completed(["1-1", "1-2"])
    assert_true(ok)
    assert_eq(_save.load_completed(), ["1-1", "1-2"])

func test_empty_roundtrip():
    assert_true(_save.save_completed([]))
    assert_eq(_save.load_completed(), [])

func test_save_overwrites_previous():
    _save.save_completed(["1-1"])
    _save.save_completed(["1-1", "1-2", "2-1"])
    assert_eq(_save.load_completed(), ["1-1", "1-2", "2-1"])

func test_corrupt_json_returns_empty():
    _write_raw("{{{ not json")
    assert_eq(_save.load_completed(), [])
    assert_engine_error_count(1, "坏 JSON 触发引擎解析错误")
    assert_push_warning("存档损坏")

func test_wrong_version_returns_empty():
    _write_raw('{"version": 99, "completed": ["1-1"]}')
    assert_eq(_save.load_completed(), [])
    assert_push_warning("存档版本不兼容")

func test_non_string_entries_skipped():
    _write_raw('{"version": 1, "completed": ["1-1", 42, null]}')
    assert_eq(_save.load_completed(), ["1-1"])
