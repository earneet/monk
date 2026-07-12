extends GutTest

func test_has_back_button():
    var hud := HUD.new()
    add_child(hud)
    var found := false
    for c in hud.get_children():
        if c is Button and (c as Button).text == "返回列表":
            found = true
    assert_true(found)

func test_back_button_emits_back_pressed():
    var hud := HUD.new()
    add_child(hud)
    var emitted := [false]
    hud.back_pressed.connect(func(): emitted[0] = true)
    for c in hud.get_children():
        if c is Button and (c as Button).text == "返回列表":
            (c as Button).pressed.emit()
            break
    assert_true(emitted[0])
