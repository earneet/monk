extends GutTest

func test_bridge_not_placed_when_lever_absent():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(2, 0)
    bridge.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), bridge)
    assert_false(ms.can_pass(Vector2i(2, 0), [Vector2i(1, 1)]))

func test_bridge_placed_when_lever_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(2, 0)
    bridge.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), bridge)
    assert_true(ms.can_pass(Vector2i(2, 0), [Vector2i(0, 0)]))
