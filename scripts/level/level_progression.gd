class_name LevelProgression
extends RefCounted

var _sequence: Array[String] = []
var _completed: Dictionary = {}
var _next_map: Dictionary = {}

func _init(chapters: Array, completed: Array = [], next_map: Dictionary = {}) -> void:
    for ch in chapters:
        var chapter: ChapterResource = ch as ChapterResource
        for lvl in chapter.main_levels:
            var level: LevelResource = lvl as LevelResource
            _sequence.append(level.meta.id)
    for id in completed:
        _completed[id] = true
    _next_map = next_map

func unlocked_ids() -> Array[String]:
    var result: Array[String] = []
    if _sequence.is_empty():
        return result
    result.append(_sequence[0])
    for id in _completed:
        for nxt in _resolve_next(id):
            if not (nxt in result):
                result.append(nxt)
    return result

func _resolve_next(id: String) -> Array[String]:
    if _next_map.has(id):
        var value: Variant = _next_map[id]
        if value is Array:
            var arr := value as Array
            if arr.size() > 0:
                var typed: Array[String] = []
                for x in arr:
                    typed.append(x)
                return typed
    var idx := _sequence.find(id)
    if idx >= 0 and idx + 1 < _sequence.size():
        return [_sequence[idx + 1]]
    return []

func highlighted_id() -> String:
    var unlocked := unlocked_ids()
    for id in unlocked:
        if not _completed.has(id):
            return id
    return ""

func mark_completed(level_id: String) -> void:
    _completed[level_id] = true

func is_completed(level_id: String) -> bool:
    return _completed.has(level_id)

func completed_ids() -> Array[String]:
    var result: Array[String] = []
    for id in _completed:
        result.append(id)
    return result
