class_name SaveSystem
extends Node

const SAVE_VERSION := 1

var save_path: String = "user://progress.json"

func load_completed() -> Array[String]:
    if not FileAccess.file_exists(save_path):
        return []
    var f := FileAccess.open(save_path, FileAccess.READ)
    if f == null:
        push_warning("SaveSystem: 存档无法打开,视为空进度: %s" % save_path)
        return []
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is not Dictionary:
        push_warning("SaveSystem: 存档损坏(非 JSON 对象),视为空进度: %s" % save_path)
        return []
    var data: Dictionary = parsed
    if data.get("version", 0) != SAVE_VERSION:
        push_warning("SaveSystem: 存档版本不兼容(%s),视为空进度: %s" % [str(data.get("version")), save_path])
        return []
    var result: Array[String] = []
    var completed = data.get("completed", [])
    if completed is Array:
        for id in completed:
            if id is String:
                result.append(id)
    return result

func save_completed(ids: Array) -> bool:
    var f := FileAccess.open(save_path, FileAccess.WRITE)
    if f == null:
        push_warning("SaveSystem: 存档无法写入: %s" % save_path)
        return false
    f.store_string(JSON.stringify({"version": SAVE_VERSION, "completed": ids}, "\t"))
    f.close()
    return true
