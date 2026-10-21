class_name UITheme
extends RefCounted

const PAPER := Color(0.96, 0.93, 0.86, 0.94)
const PAPER_HOVER := Color(1.0, 0.98, 0.92, 0.97)
const PAPER_PRESSED := Color(0.87, 0.84, 0.76, 0.97)
const INK := Color(0.16, 0.14, 0.12)
const INK_SOFT := Color(0.35, 0.32, 0.28, 0.9)
const ACCENT := Color(0.62, 0.28, 0.12)

static func paper_panel(radius: int = 10, border: int = 2) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = PAPER
    sb.border_color = INK_SOFT
    sb.set_border_width_all(border)
    sb.set_corner_radius_all(radius)
    sb.shadow_color = Color(0.1, 0.08, 0.05, 0.25)
    sb.shadow_size = 4
    sb.shadow_offset = Vector2(0, 2)
    return sb

static func style_button(b: Button) -> void:
    b.add_theme_stylebox_override("normal", _button_box(PAPER))
    b.add_theme_stylebox_override("hover", _button_box(PAPER_HOVER))
    b.add_theme_stylebox_override("pressed", _button_box(PAPER_PRESSED))
    b.add_theme_color_override("font_color", INK)
    b.add_theme_color_override("font_hover_color", INK)
    b.add_theme_color_override("font_pressed_color", INK)
    b.add_theme_color_override("font_focus_color", INK)

static func _button_box(bg: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = INK_SOFT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(10)
    sb.content_margin_left = 10.0
    sb.content_margin_right = 10.0
    sb.content_margin_top = 4.0
    sb.content_margin_bottom = 4.0
    return sb

static func add_background(parent: Control, tex: Texture2D) -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = tex
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    tr.set_anchors_preset(Control.PRESET_FULL_RECT)
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(tr)
    return tr
