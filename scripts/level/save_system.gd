# 无 class_name:引擎禁止 autoload 与 class_name 同名,类型经 autoload 全局名暴露
extends Node

const AUTOLOAD_PATH := "/root/SaveSystem"
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

# 先写 .tmp 再整体替换:open(WRITE) 会立刻截断旧档,直写时写一半崩溃即丢全部进度
func save_completed(ids: Array[String]) -> bool:
    var tmp_path := save_path + ".tmp"
    var f := FileAccess.open(tmp_path, FileAccess.WRITE)
    if f == null:
        push_warning("SaveSystem: 存档无法写入: %s" % tmp_path)
        return false
    f.store_string(JSON.stringify({"version": SAVE_VERSION, "completed": ids}, "\t"))
    var write_err := f.get_error()
    f.close()
    if write_err != OK:
        push_warning("SaveSystem: 存档写入不完整(%s),保留旧档: %s" % [str(write_err), tmp_path])
        DirAccess.remove_absolute(tmp_path)
        return false
    var err := DirAccess.rename_absolute(tmp_path, save_path)
    if err != OK:
        push_warning("SaveSystem: 存档替换失败(%s): %s" % [str(err), save_path])
        DirAccess.remove_absolute(tmp_path)
        return false
    return true
