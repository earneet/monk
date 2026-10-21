class_name HUD
extends Control

signal undo_pressed()
signal reset_pressed()
signal back_pressed()

var _win_label: Label

func _ready() -> void:
    var undo := _make_button("撤销(Z)", Vector2(10, 10))
    undo.pressed.connect(func(): undo_pressed.emit())
    add_child(undo)

    var reset := _make_button("重置(R)", Vector2(110, 10))
    reset.pressed.connect(func(): reset_pressed.emit())
    add_child(reset)

    var back := _make_button("返回列表", Vector2(210, 10))
    back.pressed.connect(func(): back_pressed.emit())
    add_child(back)

    _win_label = Label.new()
    _win_label.text = ""
    _win_label.position = Vector2(10, 50)
    _win_label.add_theme_font_size_override("font_size", 28)
    _win_label.add_theme_color_override("font_color", UITheme.ACCENT)
    _win_label.add_theme_color_override("font_outline_color", UITheme.PAPER)
    _win_label.add_theme_constant_override("outline_size", 8)
    add_child(_win_label)

func _make_button(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    UITheme.style_button(b)
    return b

func show_win() -> void:
    _win_label.text = "✦  通关!  ✦"

func clear_win() -> void:
    _win_label.text = ""
