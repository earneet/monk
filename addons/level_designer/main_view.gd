@tool
class_name LevelDesignerMainView
extends Control

var work: WorkLevelResource
var canvas: LevelCanvas
var size_x_spin: SpinBox
var size_y_spin: SpinBox
var goal_check: CheckBox
var mode_option: OptionButton
var lever_option: OptionButton
var period_spin: SpinBox

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
    var undo_btn := Button.new()
    undo_btn.text = "撤销"
    undo_btn.pressed.connect(_on_undo)
    toolbar.add_child(undo_btn)
    var export_btn := Button.new()
    export_btn.text = "导出 .tres"
    export_btn.pressed.connect(_on_export)
    toolbar.add_child(export_btn)
    var mech_bar := HBoxContainer.new()
    vbox.add_child(mech_bar)
    var ml := Label.new()
    ml.text = "机制:"
    mech_bar.add_child(ml)
    mode_option = OptionButton.new()
    mode_option.add_item("无(画路径)", LevelCanvas.Mode.NONE)
    mode_option.add_item("机关(自动id)", LevelCanvas.Mode.LEVER)
    mode_option.add_item("门", LevelCanvas.Mode.DOOR)
    mode_option.add_item("传送(自动配对)", LevelCanvas.Mode.PORTAL)
    mode_option.add_item("桥", LevelCanvas.Mode.BRIDGE)
    mode_option.add_item("动态水", LevelCanvas.Mode.DWATER)
    mode_option.item_selected.connect(_on_mode_changed)
    mech_bar.add_child(mode_option)
    var ll := Label.new()
    ll.text = "控制机关(门/桥):"
    mech_bar.add_child(ll)
    lever_option = OptionButton.new()
    lever_option.item_selected.connect(_on_lever_selected)
    mech_bar.add_child(lever_option)
    var pl := Label.new()
    pl.text = "period(动态水):"
    mech_bar.add_child(pl)
    period_spin = SpinBox.new()
    period_spin.min_value = 2
    period_spin.max_value = 20
    period_spin.value = 4
    period_spin.value_changed.connect(_on_period_changed)
    mech_bar.add_child(period_spin)
    canvas = LevelCanvas.new()
    canvas.work = work
    canvas.cell_size = 48
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    vbox.add_child(canvas)
    _on_mode_changed(0)

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

func _on_undo() -> void:
    canvas.work.undo()
    canvas.queue_redraw()

func _on_mode_changed(idx: int) -> void:
    canvas.mode = idx as LevelCanvas.Mode
    _refresh_lever_options()

func _refresh_lever_options() -> void:
    lever_option.clear()
    for m in work.mechanics:
        if m is LeverData:
            lever_option.add_item((m as LeverData).id)
    if lever_option.item_count > 0:
        lever_option.select(0)
        _on_lever_selected(0)
    else:
        canvas.mech_lever_ids = []

func _on_lever_selected(idx: int) -> void:
    if idx >= 0 and idx < lever_option.item_count:
        canvas.mech_lever_ids = [lever_option.get_item_text(idx)]

func _on_period_changed(_v: float) -> void:
    canvas.mech_period = int(period_spin.value)

func _on_export() -> void:
    var errs := PathValidator.validate(work.path, work.size)
    errs += MechanicOrderValidator.validate(work.path, work.mechanics)
    if errs.size() > 0:
        print("[LevelDesigner] 校验失败,不导出: ", errs)
        return
    var lr := Exporter.export_level(work)
    var path := "res://resources/levels/%s.tres" % work.meta.id
    var err := ResourceSaver.save(lr, path)
    if err == OK:
        print("[LevelDesigner] 已导出: ", path)
        var data_errs := LevelSystem.new().validate(lr)
        if data_errs.size() > 0:
            print("[LevelDesigner] 数据完整性警告(运行时 validate): ", data_errs)
    else:
        print("[LevelDesigner] 导出失败: ", err)
