class_name DynamicWaterData
extends MechanicData

@export var period: int = 4

func can_pass(path: Array, _ms: MechanicSystem) -> bool:
    if period < 2:
        return true
    var phase: int = path.size() % period
    @warning_ignore("integer_division")
    return phase < (period + 1) / 2
