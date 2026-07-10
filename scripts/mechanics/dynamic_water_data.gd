class_name DynamicWaterData
extends MechanicData

@export var period: int = 4

func can_pass(path: Array, _ms: MechanicSystem) -> bool:
    var phase: int = path.size() % period
    @warning_ignore("integer_division")
    return phase < (period + 1) / 2
