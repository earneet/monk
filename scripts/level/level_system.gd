class_name LevelSystem
extends Resource

var grid_model: GridModel
var mechanic_system: MechanicSystem
var path_state: PathState
var _level: LevelResource

func load(level: LevelResource) -> void:
    _level = level
    grid_model = GridModel.new()
    grid_model.size = level.size
    mechanic_system = MechanicSystem.new()
    for y in range(level.size.y):
        for x in range(level.size.x):
            var coord := Vector2i(x, y)
            var t: int = level.tiles[y][x]
            match t:
                LevelResource.TileType.WALL:
                    var d := WallData.new()
                    d.coord = coord
                    mechanic_system.set_data(coord, d)
                    grid_model.set_mechanic_data(coord, d)
                LevelResource.TileType.FLOWING_WATER:
                    var d := FlowingWaterData.new()
                    d.coord = coord
                    mechanic_system.set_data(coord, d)
                    grid_model.set_mechanic_data(coord, d)
                _:
                    pass
    for m in level.mechanics:
        mechanic_system.set_data(m.coord, m)
        grid_model.set_mechanic_data(m.coord, m)
        if m is LeverData:
            var lever := m as LeverData
            mechanic_system.register_lever(lever.id, lever.coord)
    var portals_by_id: Dictionary = {}
    for m in level.mechanics:
        if m is PortalData:
            var pid: String = (m as PortalData).pair_id
            var arr: Array = portals_by_id.get(pid, [])
            arr.append(m.coord)
            portals_by_id[pid] = arr
    for id in portals_by_id:
        var coords: Array = portals_by_id[id]
        if coords.size() == 2 and coords[0] != coords[1]:
            mechanic_system.register_portal(coords[0], coords[1])
    for e in validate(level):
        push_error(e)
    path_state = PathState.new()
    path_state.setup(mechanic_system, grid_model, level.start)
    path_state.set_need_cover(need_cover())

func need_cover() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(_level.size.y):
        for x in range(_level.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = mechanic_system.data_at(coord)
            if data == null or data.counts_for_need_cover():
                result.append(coord)
    return result

func check_win() -> bool:
    return path_state.is_covered() and _goal_satisfied()

func _goal_satisfied() -> bool:
    if _level.goal == Vector2i(-1, -1):
        return true
    return path_state.path[path_state.path.size() - 1] == _level.goal

func validate(level: LevelResource) -> Array[String]:
    var errors: Array[String] = []
    var known_lever_ids: Dictionary = {}
    for m in level.mechanics:
        if m is LeverData:
            known_lever_ids[(m as LeverData).id] = true
    for m in level.mechanics:
        if m is DynamicWaterData:
            var dw := m as DynamicWaterData
            if dw.period < 2:
                errors.append("DynamicWaterData.period 必须 >= 2 (当前 %d)" % dw.period)
        elif m is DoorData:
            _validate_lever_ids(errors, (m as DoorData).lever_ids, "DoorData", known_lever_ids)
        elif m is BridgeData:
            _validate_lever_ids(errors, (m as BridgeData).lever_ids, "BridgeData", known_lever_ids)
    var portal_counts: Dictionary = {}
    var portal_coords: Dictionary = {}
    var portal_at: Dictionary = {}
    for m in level.mechanics:
        if m is PortalData:
            var pid := (m as PortalData).pair_id
            if pid == "":
                errors.append("PortalData.pair_id 不能为空")
            portal_counts[pid] = portal_counts.get(pid, 0) + 1
            var arr: Array = portal_coords.get(pid, [])
            arr.append(m.coord)
            portal_coords[pid] = arr
            portal_at[m.coord] = true
    for pid in portal_counts:
        if portal_counts[pid] != 2:
            errors.append("PortalData.pair_id '%s' 须恰好成对(出现 %d 次)" % [pid, portal_counts[pid]])
        elif portal_coords[pid][0] == portal_coords[pid][1]:
            errors.append("PortalData.pair_id '%s' 两端坐标不能相同" % pid)
    if portal_at.has(level.start):
        errors.append("起点不能是传送门")
    if level.goal != Vector2i(-1, -1) and portal_at.has(level.goal):
        errors.append("终点不能是传送门")
    return errors

func _validate_lever_ids(errors: Array[String], lever_ids: Array[String], owner: String, known: Dictionary) -> void:
    if lever_ids.is_empty():
        errors.append("%s.lever_ids 不能为空" % owner)
        return
    for id in lever_ids:
        if not known.has(id):
            errors.append("%s 引用了不存在的机关 id: %s" % [owner, id])
