class_name HUD
extends Control

signal undo_pressed()
signal reset_pressed()

var _win_label: Label

func _ready() -> void:
    var undo := Button.new()
    undo.text = "撤销(Z)"
    undo.position = Vector2(10, 10)
    undo.pressed.connect(func(): undo_pressed.emit())
    add_child(undo)

    var reset := Button.new()
    reset.text = "重置(R)"
    reset.position = Vector2(110, 10)
    reset.pressed.connect(func(): reset_pressed.emit())
    add_child(reset)

    _win_label = Label.new()
    _win_label.text = ""
    _win_label.position = Vector2(10, 50)
    _win_label.add_theme_font_size_override("font_size", 24)
    add_child(_win_label)

func show_win() -> void:
    _win_label.text = "✦  通关!  ✦"

func clear_win() -> void:
    _win_label.text = ""
