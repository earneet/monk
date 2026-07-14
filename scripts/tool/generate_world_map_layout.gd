extends SceneTree

const LAYOUT_PATH := "res://resources/menu/world_map_layout.tres"
const CH1_PATH := "res://resources/chapters/chapter_01.tres"
const CH2_PATH := "res://resources/chapters/chapter_02.tres"

var _exit_code := 0

func _init() -> void:
    _run()
    quit(_exit_code)

func _run() -> void:
    DirAccess.make_dir_recursive_absolute("res://resources/menu/")
    var layout := WorldMapLayout.new()
    layout.canvas_size = Vector2(720, 1280)
    var ch1 := _chapter("ch1", Vector2(360, 320), Color(0.42, 0.56, 0.35), "🏯", Vector2(720, 960))
    ch1.levels = _levels(["1-1", "1-2", "1-3", "1-4", "1-5"],
        [Vector2(140, 140), Vector2(360, 260), Vector2(560, 400), Vector2(320, 580), Vector2(180, 780)])
    var ch2 := _chapter("ch2", Vector2(360, 820), Color(0.55, 0.42, 0.26), "⛰️", Vector2(720, 760))
    ch2.levels = _levels(["2-1", "2-2", "2-3"],
        [Vector2(160, 180), Vector2(440, 360), Vector2(300, 600)])
    layout.chapters = [ch1, ch2]
    var chapters := [load(CH1_PATH) as ChapterResource, load(CH2_PATH) as ChapterResource]
    var errors := layout.validate(chapters)
    if not errors.is_empty():
        for e in errors:
            push_error(e)
        _exit_code = 1
        return
    var err := ResourceSaver.save(layout, LAYOUT_PATH)
    if err != OK:
        push_error("保存失败: %s" % err)
        _exit_code = 1
        return
    print("world_map_layout.tres 已生成")

func _chapter(cid: String, pos: Vector2, color: Color, icon: String, path_size: Vector2) -> ChapterMapEntry:
    var e := ChapterMapEntry.new()
    e.chapter_id = cid
    e.position = pos
    e.theme_color = color
    e.icon = icon
    e.path_size = path_size
    return e

func _levels(ids: Array, positions: Array) -> Array[LevelMapEntry]:
    var out: Array[LevelMapEntry] = []
    for i in range(ids.size()):
        var le := LevelMapEntry.new()
        le.level_id = ids[i]
        le.position = positions[i]
        out.append(le)
    return out
