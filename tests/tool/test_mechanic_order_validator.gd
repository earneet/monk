extends GutTest

func test_lever_before_door_passes():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(1, 0)
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    door.coord = Vector2i(2, 0)
    var mechs: Array[MechanicData] = [lever, door]
    assert_eq(MechanicOrderValidator.validate(path, mechs), [])

func test_lever_after_door_fails():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(2, 0)
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    door.coord = Vector2i(1, 0)
    var mechs: Array[MechanicData] = [lever, door]
    var errs := MechanicOrderValidator.validate(path, mechs)
    assert_true(errs.any(func(e: String): return e.find("门") >= 0))

func test_portal_pair_adjacent_passes():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var pa := PortalData.new()
    pa.pair_id = "P1"
    pa.coord = Vector2i(1, 0)
    var pb := PortalData.new()
    pb.pair_id = "P1"
    pb.coord = Vector2i(2, 0)
    var mechs: Array[MechanicData] = [pa, pb]
    assert_eq(MechanicOrderValidator.validate(path, mechs), [])

func test_portal_pair_not_adjacent_fails():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
    var pa := PortalData.new()
    pa.pair_id = "P1"
    pa.coord = Vector2i(1, 0)
    var pb := PortalData.new()
    pb.pair_id = "P1"
    pb.coord = Vector2i(3, 0)
    var mechs: Array[MechanicData] = [pa, pb]
    var errs := MechanicOrderValidator.validate(path, mechs)
    assert_true(errs.any(func(e: String): return e.find("相邻") >= 0))

func test_dynamic_water_low_phase_passes():
    var path: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 0)]
    var dw := DynamicWaterData.new()
    dw.period = 2
    dw.coord = Vector2i(1, 0)
    var mechs: Array[MechanicData] = [dw]
    assert_eq(MechanicOrderValidator.validate(path, mechs), [])

func test_dynamic_water_high_phase_fails():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
    var dw := DynamicWaterData.new()
    dw.period = 2
    dw.coord = Vector2i(1, 0)
    var mechs: Array[MechanicData] = [dw]
    var errs := MechanicOrderValidator.validate(path, mechs)
    assert_true(errs.any(func(e: String): return e.find("低水位") >= 0))
