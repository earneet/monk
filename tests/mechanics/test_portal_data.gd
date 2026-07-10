extends GutTest

func test_portal_default_can_pass_true():
    var ms := MechanicSystem.new()
    var p := PortalData.new()
    p.coord = Vector2i(1, 0)
    ms.set_data(Vector2i(1, 0), p)
    assert_true(ms.can_pass(Vector2i(1, 0), []))

func test_portal_counts_for_need_cover():
    var p := PortalData.new()
    assert_true(p.counts_for_need_cover())

func test_register_and_pair_of():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(2, 0), Vector2i(5, 5))
    assert_eq(ms.pair_of(Vector2i(2, 0)), Vector2i(5, 5))
    assert_eq(ms.pair_of(Vector2i(5, 5)), Vector2i(2, 0))

func test_pair_of_unregistered_returns_self():
    var ms := MechanicSystem.new()
    assert_eq(ms.pair_of(Vector2i(9, 9)), Vector2i(9, 9))

func test_portal_pairs_dedup():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(0, 0), Vector2i(1, 1))
    var pairs: Array = ms.portal_pairs()
    assert_eq(pairs.size(), 1)
    var pair: Array = pairs[0]
    assert_true(pair.has(Vector2i(0, 0)) and pair.has(Vector2i(1, 1)))
