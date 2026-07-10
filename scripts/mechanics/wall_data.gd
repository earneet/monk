class_name WallData
extends MechanicData

func can_pass(_path: Array, _ms: MechanicSystem) -> bool:
    return false

func counts_for_need_cover() -> bool:
    return false
