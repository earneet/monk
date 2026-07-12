class_name Exporter

static func export_level(wlr: WorkLevelResource) -> LevelResource:
    var lr := LevelResource.new()
    lr.size = wlr.size
    lr.tiles = Filler.fill(wlr)
    lr.mechanics = wlr.mechanics
    if wlr.path.size() > 0:
        lr.start = wlr.path[0]
        lr.goal = wlr.path[wlr.path.size() - 1] if wlr.has_goal else Vector2i(-1, -1)
    else:
        lr.start = Vector2i(-1, -1)
        lr.goal = Vector2i(-1, -1)
    lr.meta = wlr.meta
    return lr
