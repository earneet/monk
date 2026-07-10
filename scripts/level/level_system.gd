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
