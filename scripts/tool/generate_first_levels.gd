extends SceneTree

const LEVELS_DIR := "res://resources/levels"
const CHAPTERS_DIR := "res://resources/chapters"

var _exit_code := 0

func _init() -> void:
    _run()
    quit(_exit_code)


func _run() -> void:
    DirAccess.make_dir_recursive_absolute(LEVELS_DIR)
    DirAccess.make_dir_recursive_absolute(CHAPTERS_DIR)
    var defs := _level_def()
    for def in defs:
        var lr := _build_level(def)
        if lr == null:
            _exit_code = 1
            return
        var path: String = "%s/%s.tres" % [LEVELS_DIR, def["file"]]
        var err := ResourceSaver.save(lr, path)
        if err != OK:
            push_error("保存失败 %s: %d" % [path, err])
            _exit_code = 1
            return
        print("产出关卡 %s -> %s" % [def["meta_id"], path])
    if not _save_chapter("ch1", "前院", ["l1_1", "l1_2", "l1_3", "l1_4", "l1_5"], "chapter_01"):
        _exit_code = 1
        return
    if not _save_chapter("ch2", "后山", ["l2_1", "l2_2", "l2_3"], "chapter_02"):
        _exit_code = 1
        return
    print("全部完成: 8 关 + 2 章")


func _level_def() -> Array:
    return [
        _def("l1_1", "1-1", "初扫", 1, Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", []),
        _def("l1_2", "1-2", "石径", 2, Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1), "walk", []),
        _def("l1_3", "1-3", "曲径", 3, Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1), "walk", []),
        _def("l1_4", "1-4", "溪畔", 4, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "walk", []),
        _def("l1_5", "1-5", "前院终", 5, Vector2i(6, 6), Vector2i(0, 0), Vector2i(5, 5), "walk", []),
        _def("l2_1", "2-1", "叩门", 6, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "walk", ["lv1"]),
        _def("l2_2", "2-2", "重门", 7, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "walk", ["lv1", "lv2"]),
        _def("l2_3", "2-3", "后山终", 8, Vector2i(7, 7), Vector2i(0, 0), Vector2i(6, 6), "walk", ["lv1"]),
    ]


func _def(file: String, meta_id: String, display: String, diff: int, size: Vector2i, start: Vector2i, goal: Vector2i, gen: String, lever_ids: Array) -> Dictionary:
    return {
        "file": file,
        "meta_id": meta_id,
        "display": display,
        "diff": diff,
        "size": size,
        "start": start,
        "goal": goal,
        "gen": gen,
        "lever_ids": lever_ids,
    }


func _build_level(def: Dictionary) -> LevelResource:
    var meta_id: String = def["meta_id"]
    var wlr := WorkLevelResource.new()
    wlr.size = def["size"]
    wlr.meta = _make_meta(meta_id, def["display"], def["diff"])
    wlr.chapter_id = "ch1" if meta_id.begins_with("1") else "ch2"
    wlr.path = _gen_path(def)
    if meta_id == "1-3":
        _add_bottleneck(wlr)
    var goal: Vector2i = def["goal"]
    wlr.has_goal = goal.x >= 0
    var lever_ids: Array = def["lever_ids"]
    if not lever_ids.is_empty():
        wlr.mechanics = _make_lever_doors(lever_ids, wlr.path)
        var mo_errs := MechanicOrderValidator.validate(wlr.path, wlr.mechanics)
        if not mo_errs.is_empty():
            push_error("MechanicOrderValidator %s: %s" % [meta_id, mo_errs])
            return null
    var lr := Exporter.export_level(wlr)
    var ls := LevelSystem.new()
    var ls_errs := ls.validate(lr)
    if not ls_errs.is_empty():
        push_error("LevelSystem.validate %s: %s" % [meta_id, ls_errs])
        return null
    return lr


func _gen_path(def: Dictionary) -> Array[Vector2i]:
    var gen: String = def["gen"]
    var size: Vector2i = def["size"]
    if gen == "heuristic":
        return PathGenerator.generate_heuristic(size)
    var start: Vector2i = def["start"]
    var goal: Vector2i = def["goal"]
    var end := goal if goal.x >= 0 else Vector2i(-1, -1)
    var lever_ids: Array = def["lever_ids"]
    if lever_ids.is_empty():
        return PathGenerator.generate_random_walk(size, start, end)
    var min_len: int = 15 if size.x >= 7 else 12
    return _gen_path_with_min(size, start, end, min_len)


func _gen_path_with_min(size: Vector2i, start: Vector2i, end: Vector2i, min_len: int, max_tries: int = 20) -> Array[Vector2i]:
    var best: Array[Vector2i] = []
    for i in range(max_tries):
        var p := PathGenerator.generate_random_walk(size, start, end)
        if p.size() > best.size():
            best = p
        if p.size() >= min_len:
            return p
    push_warning("random_walk 未达 min_len=%d,用最长 %d" % [min_len, best.size()])
    return best


func _make_meta(meta_id: String, display: String, diff: int) -> LevelMeta:
    var m := LevelMeta.new()
    m.id = meta_id
    m.display_name = display
    m.difficulty = diff
    return m


func _make_lever_doors(lever_ids: Array, path: Array[Vector2i]) -> Array[MechanicData]:
    var mechanics: Array[MechanicData] = []
    var n := path.size()
    var lever_base := n / 3
    var door_base := (n * 2) / 3
    for i in range(lever_ids.size()):
        var lid: String = lever_ids[i]
        var lever := LeverData.new()
        lever.id = lid
        lever.coord = path[clampi(lever_base + i, 0, n - 1)]
        var door := DoorData.new()
        door.lever_ids = [lid]
        door.coord = path[clampi(door_base + i, 0, n - 1)]
        mechanics.append(lever)
        mechanics.append(door)
    return mechanics


func _add_bottleneck(wlr: WorkLevelResource) -> void:
    var path_set: Dictionary = {}
    for c in wlr.path:
        path_set[c] = true
    var added := 0
    for y in range(1, wlr.size.y - 1):
        for x in range(1, wlr.size.x - 1):
            var coord := Vector2i(x, y)
            if not path_set.has(coord):
                wlr.obstacle_overrides[coord] = "WALL"
                added += 1
                if added >= 2:
                    return


func _save_chapter(ch_id: String, display: String, level_files: Array, file_name: String) -> bool:
    var ch := ChapterResource.new()
    ch.id = ch_id
    ch.display_name = display
    for f in level_files:
        var p: String = "%s/%s.tres" % [LEVELS_DIR, f]
        ch.main_levels.append(load(p))
    var path: String = "%s/%s.tres" % [CHAPTERS_DIR, file_name]
    var err := ResourceSaver.save(ch, path)
    if err != OK:
        push_error("保存章节失败 %s: %d" % [path, err])
        return false
    print("产出章节 %s -> %s" % [ch_id, path])
    return true
