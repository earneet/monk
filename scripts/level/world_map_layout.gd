class_name WorldMapLayout
extends Resource

@export var canvas_size: Vector2
@export var chapters: Array[ChapterMapEntry] = []

func validate(loaded_chapters: Array) -> Array[String]:
    var errors: Array[String] = []
    var loaded: Dictionary = {}
    for ch in loaded_chapters:
        var c: ChapterResource = ch as ChapterResource
        loaded[c.id] = c
    var layout_ids: Dictionary = {}
    for entry in chapters:
        var e: ChapterMapEntry = entry as ChapterMapEntry
        if layout_ids.has(e.chapter_id):
            errors.append("重复的 chapter_id: %s" % e.chapter_id)
        layout_ids[e.chapter_id] = true
    for cid in layout_ids:
        if not loaded.has(cid):
            errors.append("布局含未知 chapter_id: %s" % cid)
    for cid in loaded:
        if not layout_ids.has(cid):
            errors.append("章节 %s 缺布局坐标" % cid)
    for entry in chapters:
        var e: ChapterMapEntry = entry as ChapterMapEntry
        if not loaded.has(e.chapter_id):
            continue
        var ch: ChapterResource = loaded[e.chapter_id] as ChapterResource
        var meta_ids: Array[String] = []
        for lvl in ch.main_levels:
            meta_ids.append((lvl as LevelResource).meta.id)
        var layout_lvl: Dictionary = {}
        for le in e.levels:
            layout_lvl[(le as LevelMapEntry).level_id] = true
        for mid in meta_ids:
            if not layout_lvl.has(mid):
                errors.append("章节 %s 缺关卡 %s 坐标" % [e.chapter_id, mid])
        for lid in layout_lvl:
            if not (lid in meta_ids):
                errors.append("章节 %s 布局含未知关卡 %s" % [e.chapter_id, lid])
        if e.levels.size() == meta_ids.size():
            for i in range(e.levels.size()):
                if (e.levels[i] as LevelMapEntry).level_id != meta_ids[i]:
                    errors.append("章节 %s 关卡顺序不一致(位置 %d)" % [e.chapter_id, i])
                    break
    return errors
