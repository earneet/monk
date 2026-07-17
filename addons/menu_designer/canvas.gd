@tool
class_name MenuCanvas
extends Control

const NODE_SIZE := Vector2(72, 48)

var _layout: WorldMapLayout
var _chapters: Array = []
var _mode: String = "world"
var _chapter_index: int = 0
var _nodes: Array = []
var _moving: Resource = null
var _move_offset: Vector2 = Vector2.ZERO
var _linking_from: Resource = null
var _linking_mouse: Vector2 = Vector2.ZERO

func build(layout: WorldMapLayout, chapters: Array, mode: String, chapter_index: int) -> void:
    _layout = layout
    _chapters = chapters
    _mode = mode
    _chapter_index = chapter_index
    _rebuild_nodes()

func _rebuild_nodes() -> void:
    _nodes = []
    if _layout == null:
        queue_redraw()
        return
    if _mode == "world":
        _nodes = _layout.chapters
    elif _chapter_index < _layout.chapters.size():
        _nodes = (_layout.chapters[_chapter_index] as ChapterMapEntry).levels
    queue_redraw()

func _node_id(entry: Resource) -> String:
    if entry is ChapterMapEntry:
        return (entry as ChapterMapEntry).chapter_id
    return (entry as LevelMapEntry).level_id

func _node_pos(entry: Resource) -> Vector2:
    if entry is ChapterMapEntry:
        return (entry as ChapterMapEntry).position
    return (entry as LevelMapEntry).position

func _node_rect(entry: Resource) -> Rect2:
    return Rect2(_node_pos(entry), NODE_SIZE)

func _node_next(entry: Resource) -> Array:
    if entry is ChapterMapEntry:
        return (entry as ChapterMapEntry).next_ids
    return (entry as LevelMapEntry).next_ids

func _set_node_pos(entry: Resource, pos: Vector2) -> void:
    if entry is ChapterMapEntry:
        (entry as ChapterMapEntry).position = pos
    else:
        (entry as LevelMapEntry).position = pos

func _toggle_next(entry: Resource, target_id: String) -> void:
    var src: Array = _node_next(entry)
    var arr: Array[String] = []
    for x in src:
        arr.append(x)
    var idx := arr.find(target_id)
    if idx >= 0:
        arr.remove_at(idx)
    else:
        arr.append(target_id)
    if entry is ChapterMapEntry:
        (entry as ChapterMapEntry).next_ids = arr
    else:
        (entry as LevelMapEntry).next_ids = arr

func _id_to_pos(id: String) -> Vector2:
    for n in _nodes:
        if _node_id(n) == id:
            return _node_pos(n)
    return Vector2.ZERO

func _hit_node(pos: Vector2) -> Resource:
    for n in _nodes:
        if _node_rect(n).has_point(pos):
            return n
    return null

func _gui_input(event: InputEvent) -> void:
    if _layout == null:
        return
    if event is InputEventMouseButton and event.pressed:
        var node: Resource = _hit_node(event.position)
        if event.button_index == MOUSE_BUTTON_LEFT and node != null:
            _moving = node
            _move_offset = event.position - _node_pos(node)
        elif event.button_index == MOUSE_BUTTON_RIGHT and node != null:
            _linking_from = node
            _linking_mouse = event.position
        accept_event()
    elif event is InputEventMouseMotion:
        if _moving != null:
            _set_node_pos(_moving, event.position - _move_offset)
            queue_redraw()
            accept_event()
        elif _linking_from != null:
            _linking_mouse = event.position
            queue_redraw()
            accept_event()
    elif event is InputEventMouseButton and not event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and _moving != null:
            _moving = null
            accept_event()
        elif event.button_index == MOUSE_BUTTON_RIGHT and _linking_from != null:
            var target: Resource = _hit_node(event.position)
            if target != null and target != _linking_from:
                _toggle_next(_linking_from, _node_id(target))
            _linking_from = null
            queue_redraw()
            accept_event()

func _draw() -> void:
    for i in range(_nodes.size()):
        var from: Resource = _nodes[i]
        var targets: Array = _node_next(from)
        for tid in targets:
            var a: Vector2 = _node_pos(from) + NODE_SIZE * 0.5
            var b: Vector2 = _id_to_pos(tid) + NODE_SIZE * 0.5
            _draw_arrow(a, b, Color(0.5, 0.45, 0.3))
    var font := ThemeDB.get_default_theme().default_font
    for n in _nodes:
        var rect: Rect2 = _node_rect(n)
        draw_rect(rect, Color(0.42, 0.56, 0.35), true)
        draw_rect(rect, Color(0.2, 0.2, 0.2), false)
        draw_string(font, rect.position + Vector2(4, 18), _node_id(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
    if _linking_from != null:
        var a2: Vector2 = _node_pos(_linking_from) + NODE_SIZE * 0.5
        _draw_arrow(a2, _linking_mouse, Color(0.8, 0.3, 0.3))

func _draw_arrow(a: Vector2, b: Vector2, color: Color) -> void:
    var d := b - a
    if d.length() < 1.0:
        return
    var dir := d.normalized()
    var perp := Vector2(-dir.y, dir.x)
    var tip := b - dir * 24.0
    draw_line(a, tip, color, 2.0)
    var head := 12.0
    var wing := 6.0
    var base := tip - dir * head
    draw_line(tip, base + perp * wing, color, 2.0)
    draw_line(tip, base - perp * wing, color, 2.0)
