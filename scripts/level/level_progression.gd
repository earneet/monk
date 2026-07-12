class_name LevelProgression
extends RefCounted

var _sequence: Array[String] = []
var _completed: Dictionary = {}

func _init(chapters: Array, completed: Array = []) -> void:
    for ch in chapters:
        var chapter: ChapterResource = ch as ChapterResource
        for lvl in chapter.main_levels:
            var level: LevelResource = lvl as LevelResource
            _sequence.append(level.meta.id)
    for id in completed:
        _completed[id] = true

func unlocked_ids() -> Array[String]:
    var result: Array[String] = []
    if _sequence.is_empty():
        return result
    result.append(_sequence[0])
    for i in range(_sequence.size() - 1):
        if _completed.has(_sequence[i]):
            result.append(_sequence[i + 1])
    return result

func highlighted_id() -> String:
    for id in _sequence:
        if not _completed.has(id):
            return id
    return ""

func mark_completed(level_id: String) -> void:
    _completed[level_id] = true

func is_completed(level_id: String) -> bool:
    return _completed.has(level_id)
