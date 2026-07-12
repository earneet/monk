@tool
class_name LevelDesignerMainView
extends Control

var work: WorkLevelResource
var canvas: LevelCanvas
var size_x_spin: SpinBox
var size_y_spin: SpinBox
var goal_check: CheckBox

func _ready() -> void:
    if work == null:
        work = _new_work()
    _build_ui()

func _new_work() -> WorkLevelResource:
    var w := WorkLevelResource.new()
    w.size = Vector2i(5, 5)
    w.path = []
    w.meta = LevelMeta.new()
    w.meta.id = "new_level"
    w.meta.display_name = "New Level"
    w.meta.difficulty = 1
    return w

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(vbox)
    var toolbar := HBoxContainer.new()
    vbox.add_child(toolbar)
    var lx := Label.new()
    lx.text = "宽"
    toolbar.add_child(lx)
    size_x_spin = SpinBox.new()
    size_x_spin.min_value = 1
    size_x_spin.max_value = 30
    size_x_spin.value = work.size.x
    size_x_spin.value_changed.connect(_on_size_changed)
    toolbar.add_child(size_x_spin)
    var ly := Label.new()
    ly.text = "高"
    toolbar.add_child(ly)
    size_y_spin = SpinBox.new()
    size_y_spin.min_value = 1
    size_y_spin.max_value = 30
    size_y_spin.value = work.size.y
    size_y_spin.value_changed.connect(_on_size_changed)
    toolbar.add_child(size_y_spin)
    goal_check = CheckBox.new()
    goal_check.text = "末格为终点"
    goal_check.button_pressed = work.has_goal
    goal_check.toggled.connect(_on_goal_toggled)
    toolbar.add_child(goal_check)
    var clear_btn := Button.new()
    clear_btn.text = "清空路径"
    clear_btn.pressed.connect(_on_clear)
    toolbar.add_child(clear_btn)
    var export_btn := Button.new()
    export_btn.text = "导出 .tres"
    export_btn.pressed.connect(_on_export)
    toolbar.add_child(export_btn)
    canvas = LevelCanvas.new()
    canvas.work = work
    canvas.cell_size = 48
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    vbox.add_child(canvas)

func _on_size_changed(_v: float) -> void:
    work.size = Vector2i(int(size_x_spin.value), int(size_y_spin.value))
    var kept: Array[Vector2i] = []
    for c in work.path:
        if c.x < work.size.x and c.y < work.size.y:
            kept.append(c)
    work.path = kept
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    canvas.queue_redraw()

func _on_goal_toggled(p: bool) -> void:
    work.has_goal = p
    canvas.queue_redraw()

func _on_clear() -> void:
    work.path = []
    canvas.queue_redraw()

func _on_export() -> void:
    var errs := PathValidator.validate(work.path, work.size)
    if errs.size() > 0:
        print("[LevelDesigner] 路径无效,不导出: ", errs)
        return
    var lr := Exporter.export_level(work)
    var path := "res://resources/levels/%s.tres" % work.meta.id
    var err := ResourceSaver.save(lr, path)
    if err == OK:
        print("[LevelDesigner] 已导出: ", path)
    else:
        print("[LevelDesigner] 导出失败: ", err)
