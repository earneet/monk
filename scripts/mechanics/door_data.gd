class_name DoorData
extends MechanicData

@export var lever_ids: Array[String] = []

func can_pass(path: Array, ms: MechanicSystem) -> bool:
    return ms.is_lever_pressed(lever_ids, path)
