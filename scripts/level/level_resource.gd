class_name LevelResource
extends Resource

enum TileType { EMPTY, WALL, FLOWING_WATER }

@export var size: Vector2i
@export var tiles: Array  # 每行 Array[int](TileType 枚举值);用 Array 因 Godot 嵌套类型化数组 @export 支持有限
@export var mechanics: Array[MechanicData]
@export var start: Vector2i
@export var goal: Vector2i = Vector2i(-1, -1)
@export var meta: LevelMeta
