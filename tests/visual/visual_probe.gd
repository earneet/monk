extends Node

const SHOT_DIR := "res://.zcode/shots"
const BootScene := preload("res://scenes/boot.tscn")
const LevelScene := preload("res://scenes/level.tscn")

func _ready() -> void:
    get_window().size = Vector2i(1280, 720)
    await _shot_menu()
    await _shot_landscape()
    await _shot_mechanisms()
    get_tree().quit()

func _snap(shot_name: String) -> void:
    await RenderingServer.frame_post_draw
    var dir := ProjectSettings.globalize_path(SHOT_DIR)
    DirAccess.make_dir_recursive_absolute(dir)
    get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
    print("[shot] ", shot_name)

func _wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func _shot_menu() -> void:
    var boot := BootScene.instantiate()
    add_child(boot)
    await _wait(0.5)
    await _snap("menu_world")
    var menu: LevelMenu = boot.get_node("LevelMenu")
    menu.enter_chapter("ch1", Vector2.ZERO)
    await _wait(0.7)
    await _snap("menu_chapter")
    boot.queue_free()
    await _wait(0.1)

func _shot_landscape() -> void:
    var lv := LevelScene.instantiate()
    lv.level = _landscape_level()
    add_child(lv)
    await _wait(0.4)
    await _snap("level_landscape_start")
    for coord: Vector2i in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]:
        lv._on_move_intent(coord)
        await _wait(0.02)
    await _wait(0.08)
    await _snap("level_landscape_move")
    for coord: Vector2i in [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(0, 3), Vector2i(0, 4)]:
        lv._on_move_intent(coord)
        await _wait(0.02)
    await _wait(0.35)
    await _snap("level_landscape_swept")
    lv.queue_free()
    await _wait(0.1)

func _shot_mechanisms() -> void:
    var lv := LevelScene.instantiate()
    lv.level = _mechanism_level()
    add_child(lv)
    await _wait(0.4)
    await _snap("level_mech_start")
    for coord: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(6, 0)]:
        lv._on_move_intent(coord)
        await _wait(0.02)
    await _wait(0.35)
    await _snap("level_mech_open")
    lv.queue_free()
    await _wait(0.1)

func _landscape_level() -> LevelResource:
    var rows := [
        "000001102",
        "000001102",
        "001100002",
        "000000112",
        "011000002",
        "011000000",
        "000000000",
    ]
    return _build_level(rows, Vector2i(0, 0), Vector2i(8, 6), [
        _portal("甲", Vector2i(0, 5)),
        _portal("甲", Vector2i(8, 5)),
        _dwater(Vector2i(6, 5), 4),
    ], "shot-a")

func _mechanism_level() -> LevelResource:
    var rows := [
        "0000000",
        "0000000",
        "0000000",
        "0000000",
        "0000000",
    ]
    var lever := LeverData.new()
    lever.id = "lv1"
    lever.coord = Vector2i(1, 3)
    var door := DoorData.new()
    door.lever_ids = ["lv1"] as Array[String]
    door.coord = Vector2i(3, 1)
    var bridge := BridgeData.new()
    bridge.lever_ids = ["lv1"] as Array[String]
    bridge.coord = Vector2i(5, 1)
    return _build_level(rows, Vector2i(0, 0), Vector2i(6, 4), [
        lever, door, bridge,
        _dwater(Vector2i(6, 2), 4),
        _portal("乙", Vector2i(5, 3)),
        _portal("乙", Vector2i(0, 4)),
    ], "shot-b")

func _build_level(rows: Array, start: Vector2i, goal: Vector2i, mechanics: Array, id: String) -> LevelResource:
    var lvl := LevelResource.new()
    lvl.size = Vector2i(String(rows[0]).length(), rows.size())
    var tiles := []
    for r in rows:
        var line: Array[int] = []
        for ch in String(r):
            line.append(int(ch))
        tiles.append(line)
    lvl.tiles = tiles
    lvl.start = start
    lvl.goal = goal
    lvl.mechanics.assign(mechanics)
    var meta := LevelMeta.new()
    meta.id = id
    meta.display_name = id
    lvl.meta = meta
    return lvl

func _portal(pid: String, coord: Vector2i) -> PortalData:
    var p := PortalData.new()
    p.pair_id = pid
    p.coord = coord
    return p

func _dwater(coord: Vector2i, period: int) -> DynamicWaterData:
    var d := DynamicWaterData.new()
    d.coord = coord
    d.period = period
    return d
