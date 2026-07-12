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

var _undo_stack: Array[Callable] = []

func push_undo(cb: Callable) -> void:
    _undo_stack.append(cb)

func undo() -> bool:
    if _undo_stack.is_empty():
        return false
    var cb: Callable = _undo_stack.pop_back()
    cb.call()
    return true
