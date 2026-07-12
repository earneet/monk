class_name WorkLevelResource
extends Resource

enum FillRule { BORDER_WALL_INNER_WATER }

@export var meta: LevelMeta
@export var chapter_id: String
@export var size: Vector2i
@export var path: Array[Vector2i] = []
@export var has_goal: bool = false
@export var mechanics: Array[MechanicData] = []
@export var fill_rule: FillRule = FillRule.BORDER_WALL_INNER_WATER
@export var obstacle_overrides: Dictionary = {}
@export var notes: String
@export var version: int = 1

func undo_last_step() -> bool:
    if path.is_empty():
        return false
    var last: Vector2i = path[path.size() - 1]
    path.pop_back()
    var i := 0
    while i < mechanics.size():
        if mechanics[i].coord == last:
            mechanics.remove_at(i)
        else:
            i += 1
    return true
