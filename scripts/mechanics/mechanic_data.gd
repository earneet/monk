class_name MechanicData
extends Resource

@export var coord: Vector2i

func can_pass(_path: Array, _ms: MechanicSystem) -> bool:
    return true

func counts_for_need_cover() -> bool:
    return true
