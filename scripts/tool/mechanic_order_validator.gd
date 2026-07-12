class_name MechanicOrderValidator

static func validate(path: Array[Vector2i], mechanics: Array[MechanicData]) -> Array[String]:
    var errors: Array[String] = []
    var index_of: Dictionary = {}
    for i in range(path.size()):
        index_of[path[i]] = i
    var lever_coord_by_id: Dictionary = {}
    for m in mechanics:
        if m is LeverData:
            lever_coord_by_id[(m as LeverData).id] = m.coord
    for m in mechanics:
        if m is DoorData:
            _check_lever_before(errors, "门", m.coord, (m as DoorData).lever_ids, index_of, lever_coord_by_id)
        elif m is BridgeData:
            _check_lever_before(errors, "桥", m.coord, (m as BridgeData).lever_ids, index_of, lever_coord_by_id)
    var portals_by_id: Dictionary = {}
    for m in mechanics:
        if m is PortalData:
            var pid := (m as PortalData).pair_id
            var arr: Array = portals_by_id.get(pid, [])
            arr.append(m.coord)
            portals_by_id[pid] = arr
    for pid in portals_by_id:
        var coords: Array = portals_by_id[pid]
        if coords.size() == 2:
            var ia: int = index_of.get(coords[0], -1)
            var ib: int = index_of.get(coords[1], -1)
            if abs(ia - ib) != 1:
                errors.append("传送对 pair_id '%s' 须相邻(传送步)" % pid)
    for m in mechanics:
        if m is DynamicWaterData:
            var dw := m as DynamicWaterData
            var i: int = index_of.get(dw.coord, -1)
            if i >= 0:
                @warning_ignore("integer_division")
                var low: bool = (i % dw.period) < (dw.period + 1) / 2
                if not low:
                    errors.append("动态水 (%d,%d) 须经低水位经过" % [dw.coord.x, dw.coord.y])
    return errors

static func _check_lever_before(errors: Array[String], label: String, coord: Vector2i, lever_ids: Array[String], index_of: Dictionary, lever_coord_by_id: Dictionary) -> void:
    var my_index: int = index_of.get(coord, -1)
    var has_prior: bool = false
    for lid in lever_ids:
        var lcoord: Variant = lever_coord_by_id.get(lid)
        if lcoord != null:
            var li: int = index_of.get(lcoord, -1)
            if li >= 0 and li < my_index:
                has_prior = true
                break
    if not has_prior:
        errors.append("%s (%d,%d) 未在任何控制机关之前经过" % [label, coord.x, coord.y])
