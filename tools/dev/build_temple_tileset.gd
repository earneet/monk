extends SceneTree

## 无头构建: assets/art/temple 的贴图 → temple_tileset.tres + temple_stage.tscn
## 运行: godot --headless --path . -s res://tools/dev/build_temple_tileset.gd
## 舞台 = 整幅原画按 72px 格切成的场景图块 1:1 拼装(相邻格像素连续, 零接缝)

const CELL := 72
const TILESET_PATH := "res://assets/art/temple/temple_tileset.tres"
const STAGE_PATH := "res://tests/visual/temple_stage.tscn"
const SCENE_COLS := 30
const SCENE_ROWS := 17


func _init() -> void:
    var ids := {}
    var tileset := _build_tileset(ids)
    var err := ResourceSaver.save(tileset, TILESET_PATH)
    print("tileset saved: ", err)
    err = _build_stage(tileset, ids)
    print("stage saved: ", err)
    quit(0 if err == OK else 1)


func _build_tileset(ids: Dictionary) -> TileSet:
    var ts := TileSet.new()
    ts.tile_size = Vector2i(CELL, CELL)

    var floor_src := TileSetAtlasSource.new()
    floor_src.texture = load("res://assets/art/temple/atlas_floor.png")
    floor_src.texture_region_size = Vector2i(CELL, CELL)
    for y in range(4):
        for x in range(4):
            floor_src.create_tile(Vector2i(x, y))
    ts.add_source(floor_src, 0)

    var dir := DirAccess.open("res://assets/art/temple")
    var names: Array[String] = []
    for f in dir.get_files():
        if f.ends_with(".png") and f != "atlas_floor.png" and f != "atlas_scene.png":
            names.append(f)
    names.sort()
    for id in range(names.size()):
        var name := String(names[id].get_basename())
        var tex: Texture2D = load("res://assets/art/temple/" + names[id])
        var src := TileSetAtlasSource.new()
        src.texture = tex
        src.texture_region_size = Vector2i(CELL, CELL)
        var span := Vector2i(floori(tex.get_width() / float(CELL)), floori(tex.get_height() / float(CELL)))
        src.create_tile(Vector2i.ZERO, span)
        ts.add_source(src, id + 1)
        ids[name] = id + 1
        print("source %d = %s %s" % [id + 1, name, span])

    # 整幅原画场景图块: 单格 tile x 30x17, 用于舞台 1:1 复原
    var scene_id := names.size() + 1
    var scene_src := TileSetAtlasSource.new()
    scene_src.texture = load("res://assets/art/temple/atlas_scene.png")
    scene_src.texture_region_size = Vector2i(CELL, CELL)
    for y in range(SCENE_ROWS):
        for x in range(SCENE_COLS):
            scene_src.create_tile(Vector2i(x, y))
    ts.add_source(scene_src, scene_id)
    ids["__scene__"] = scene_id
    print("source %d = atlas_scene %dx%d cells" % [scene_id, SCENE_COLS, SCENE_ROWS])
    return ts


func _build_stage(tileset: TileSet, ids: Dictionary) -> int:
    var root := Node2D.new()
    root.name = "TempleStage"
    var scene := TileMapLayer.new()
    scene.name = "Scene"
    scene.tile_set = tileset
    root.add_child(scene)
    scene.owner = root
    var sid := int(ids["__scene__"])
    for y in range(SCENE_ROWS):
        for x in range(SCENE_COLS):
            scene.set_cell(Vector2i(x, y), sid, Vector2i(x, y))
    var ps := PackedScene.new()
    var pack_err := ps.pack(root)
    if pack_err != OK:
        return pack_err
    return ResourceSaver.save(ps, STAGE_PATH)
