# 首批关卡 headless 产关脚本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写一次性 headless GDScript 脚本,调用既有 `PathGenerator`/`Filler`/`Exporter` 产出首批 8 关 + 2 章 `.tres`,让 boot「选关 → 玩通 → 通关 → 解锁」端到端可跑。

**Architecture:** 单一脚本 `scripts/tool/generate_first_levels.gd`(`extends SceneTree`,headless `-s` 跑)。内置 8 关参数表(`Dictionary`)→ 逐关 `PathGenerator → WorkLevelResource → MechanicOrderValidator → Exporter.export_level → LevelSystem.validate → ResourceSaver.save`;再 `load` 8 关组装 2 个 `ChapterResource` 存盘。TDD:先写 `test_first_levels_generated` 定义契约(FAIL)→ 写脚本产 `.tres` → 测试 PASS。

**Tech Stack:** Godot 4.7(stable)/ 纯 GDScript / GUT 9.7

**Spec:** `docs/superpowers/specs/2026-07-12-first-levels-generation-design.md`

**环境:**
- `GODOT="C:\Program Files\godot_engine\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64.exe"`
- 命令在仓库根 `F:\workspace_2\monk` 执行,bash 语法

---

## File Structure

- Create `scripts/tool/generate_first_levels.gd` — 一次性产关脚本(`extends SceneTree`,跑完留作「8 关怎么来的」溯源)
- Create `tests/tool/test_first_levels_generated.gd` — 8 关 2 章契约测试(GUT)
- Create(脚本运行产物,非手写)`resources/levels/l1_1.tres … l1_5.tres`、`l2_1.tres … l2_3.tres`(8 关)
- Create(脚本运行产物)`resources/chapters/chapter_01.tres`、`chapter_02.tres`(2 章)

**职责边界:** 脚本只做「参数表 → 调既有工具链 → 存盘 → 守门」,不引入新产关逻辑(路径生成/填充/导出/校验全部复用 `scripts/tool/` 与 `scripts/level/` 既有纯函数)。测试只断言产物的静态契约(meta / 章引用 / 机制数量),可解性由路径优先法保证、数据自洽由既有 `test_levels_valid` 覆盖。

---

### Task 1: 写失败测试 —— 8 关 2 章契约

**Files:**
- Create: `tests/tool/test_first_levels_generated.gd`

- [ ] **Step 1: 写测试文件**

```gdscript
extends GutTest

const LEVEL_FILES := ["l1_1", "l1_2", "l1_3", "l1_4", "l1_5", "l2_1", "l2_2", "l2_3"]
const EXPECTED_IDS := ["1-1", "1-2", "1-3", "1-4", "1-5", "2-1", "2-2", "2-3"]
const EXPECTED_NAMES := ["初扫", "石径", "曲径", "溪畔", "前院终", "叩门", "重门", "后山终"]

func test_all_levels_exist_with_correct_meta() -> void:
    for i in range(LEVEL_FILES.size()):
        var p := "res://resources/levels/%s.tres" % LEVEL_FILES[i]
        assert_true(ResourceLoader.exists(p), "关卡应存在: %s" % p)
        var lr := load(p) as LevelResource
        assert_not_null(lr, "加载失败: %s" % p)
        assert_eq(lr.meta.id, EXPECTED_IDS[i], "meta.id %s" % p)
        assert_eq(lr.meta.display_name, EXPECTED_NAMES[i], "display_name %s" % p)
        assert_eq(lr.meta.difficulty, i + 1, "difficulty 应递增 %s" % p)

func test_chapter_refs() -> void:
    var ch1 := load("res://resources/chapters/chapter_01.tres") as ChapterResource
    assert_not_null(ch1, "chapter_01 应存在")
    assert_eq(ch1.id, "ch1")
    assert_eq(ch1.display_name, "前院")
    assert_eq(ch1.main_levels.size(), 5, "chapter_01 应有 5 关")
    for i in range(5):
        assert_eq((ch1.main_levels[i] as LevelResource).meta.id, EXPECTED_IDS[i], "ch1 第 %d 关 id" % i)
    var ch2 := load("res://resources/chapters/chapter_02.tres") as ChapterResource
    assert_not_null(ch2, "chapter_02 应存在")
    assert_eq(ch2.id, "ch2")
    assert_eq(ch2.display_name, "后山")
    assert_eq(ch2.main_levels.size(), 3, "chapter_02 应有 3 关")
    for i in range(3):
        assert_eq((ch2.main_levels[i] as LevelResource).meta.id, EXPECTED_IDS[5 + i], "ch2 第 %d 关 id" % i)

func test_mechanic_levels_have_lever_and_door() -> void:
    var door_files := ["l2_1", "l2_2", "l2_3"]
    var expected_doors := [1, 2, 1]
    for i in range(door_files.size()):
        var lr := load("res://resources/levels/%s.tres" % door_files[i]) as LevelResource
        var levers := 0
        var doors := 0
        for m in lr.mechanics:
            if m is LeverData:
                levers += 1
            elif m is DoorData:
                doors += 1
        assert_eq(doors, expected_doors[i], "%s 门数" % door_files[i])
        assert_eq(levers, expected_doors[i], "%s 机关数" % door_files[i])
```

- [ ] **Step 2: 跑测试,确认 FAIL(关卡 .tres 尚不存在)**

Run:
```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_first_levels_generated -gexit
```
Expected: FAIL —— `ResourceLoader.exists` 返回 false / `load` 返回 null(8 关 + 2 章 .tres 尚未产出)。

---

### Task 2: 写产关脚本并产出 8 关 2 章

**Files:**
- Create: `scripts/tool/generate_first_levels.gd`

- [ ] **Step 1: 写产关脚本(完整)**

```gdscript
extends SceneTree

const LEVELS_DIR := "res://resources/levels"
const CHAPTERS_DIR := "res://resources/chapters"

func _init() -> void:
    _run()
    quit()


func _run() -> void:
    var defs := _level_defs()
    for def in defs:
        var lr := _build_level(def)
        var path: String = "%s/%s.tres" % [LEVELS_DIR, def["file"]]
        var err := ResourceSaver.save(lr, path)
        if err != OK:
            push_error("保存失败 %s: %d" % [path, err])
            quit(1)
        print("产出关卡 %s -> %s" % [def["meta_id"], path])
    _save_chapter("ch1", "前院", ["l1_1", "l1_2", "l1_3", "l1_4", "l1_5"], "chapter_01")
    _save_chapter("ch2", "后山", ["l2_1", "l2_2", "l2_3"], "chapter_02")
    print("全部完成: 8 关 + 2 章")


func _level_def() -> Array:
    return [
        _def("l1_1", "1-1", "初扫", 1, Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", []),
        _def("l1_2", "1-2", "石径", 2, Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1), "walk", []),
        _def("l1_3", "1-3", "曲径", 3, Vector2i(5, 5), Vector2i(0, 0), Vector2i(-1, -1), "walk", []),
        _def("l1_4", "1-4", "溪畔", 4, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "walk", []),
        _def("l1_5", "1-5", "前院终", 5, Vector2i(6, 6), Vector2i(0, 0), Vector2i(5, 5), "walk", []),
        _def("l2_1", "2-1", "叩门", 6, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", ["lv1"]),
        _def("l2_2", "2-2", "重门", 7, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", ["lv1", "lv2"]),
        _def("l2_3", "2-3", "后山终", 8, Vector2i(7, 7), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", ["lv1"]),
    ]


func _def(file: String, meta_id: String, display: String, diff: int, size: Vector2i, start: Vector2i, goal: Vector2i, gen: String, lever_ids: Array) -> Dictionary:
    return {
        "file": file,
        "meta_id": meta_id,
        "display": display,
        "diff": diff,
        "size": size,
        "start": start,
        "goal": goal,
        "gen": gen,
        "lever_ids": lever_ids,
    }


func _build_level(def: Dictionary) -> LevelResource:
    var meta_id: String = def["meta_id"]
    var wlr := WorkLevelResource.new()
    wlr.size = def["size"]
    wlr.meta = _make_meta(meta_id, def["display"], def["diff"])
    wlr.chapter_id = "ch1" if meta_id.begins_with("1") else "ch2"
    wlr.path = _gen_path(def)
    var goal: Vector2i = def["goal"]
    wlr.has_goal = goal.x >= 0
    var lever_ids: Array = def["lever_ids"]
    if not lever_ids.is_empty():
        wlr.mechanics = _make_lever_doors(lever_ids, wlr.path)
        var mo_errs := MechanicOrderValidator.validate(wlr.path, wlr.mechanics)
        if not mo_errs.is_empty():
            push_error("MechanicOrderValidator %s: %s" % [meta_id, mo_errs])
            quit(1)
    var lr := Exporter.export_level(wlr)
    var ls := LevelSystem.new()
    var ls_errs := ls.validate(lr)
    if not ls_errs.is_empty():
        push_error("LevelSystem.validate %s: %s" % [meta_id, ls_errs])
        quit(1)
    return lr


func _gen_path(def: Dictionary) -> Array[Vector2i]:
    var gen: String = def["gen"]
    var size: Vector2i = def["size"]
    if gen == "heuristic":
        return PathGenerator.generate_heuristic(size)
    var start: Vector2i = def["start"]
    var goal: Vector2i = def["goal"]
    var end := goal if goal.x >= 0 else Vector2i(-1, -1)
    return PathGenerator.generate_random_walk(size, start, end)


func _make_meta(meta_id: String, display: String, diff: int) -> LevelMeta:
    var m := LevelMeta.new()
    m.id = meta_id
    m.display_name = display
    m.difficulty = diff
    return m


func _make_lever_doors(lever_ids: Array, path: Array[Vector2i]) -> Array[MechanicData]:
    var mechanics: Array[MechanicData] = []
    var n := path.size()
    var lever_base := n / 3
    var door_base := (n * 2) / 3
    for i in range(lever_ids.size()):
        var lid: String = lever_ids[i]
        var lever := LeverData.new()
        lever.id = lid
        lever.coord = path[clampi(lever_base + i, 0, n - 1)]
        var door := DoorData.new()
        door.lever_ids = [lid]
        door.coord = path[clampi(door_base + i, 0, n - 1)]
        mechanics.append(lever)
        mechanics.append(door)
    return mechanics


func _save_chapter(ch_id: String, display: String, level_files: Array, file_name: String) -> void:
    var ch := ChapterResource.new()
    ch.id = ch_id
    ch.display_name = display
    for f in level_files:
        var p: String = "%s/%s.tres" % [LEVELS_DIR, f]
        ch.main_levels.append(load(p))
    var path: String = "%s/%s.tres" % [CHAPTERS_DIR, file_name]
    var err := ResourceSaver.save(ch, path)
    if err != OK:
        push_error("保存章节失败 %s: %d" % [path, err])
        quit(1)
    print("产出章节 %s -> %s" % [ch_id, path])
```

> **已知风险点(实现期验证,不预先改):**
> 1. `_init` 内跑逻辑 + `quit()`:若 `res://` 访问在 `_init` 尚未就绪,改用 `func _initialize() -> void:` 替换 `_init`(SceneTree/MainLoop 虚函数,引擎完全初始化后调用)。
> 2. `ResourceSaver.save(lr, path)`:Godot 4.x 签名为 `(resource, path, flags)`。若报参数错,核对版本(4.7 应为 resource 在前)。
> 3. `door.lever_ids = [lid]`:`[lid]` 推断为 `Array[String]`,赋给 `@export Array[String]` 字段。若 GDScript 4.7 严格推断报警告,改为 `door.lever_ids.clear(); door.lever_ids.append(lid)`。
> 4. `def["size"]` 等 Dictionary 取值赋给 `Vector2i` 字段:GDScript 4 允许 Variant→typed 隐式运行时转换(存入即正确类型);若编辑器报警告,局部变量已显式声明类型(如 `var goal: Vector2i = def["goal"]`)兜底。
>
> **实现期实际调整(已验证,实际以 `scripts/tool/generate_first_levels.gd` 为准):**
> 5. `resources/chapters/` 首次不存在 → `ResourceSaver.save` 报 `ERR_CANT_OPEN (19)`。`_run` 开头加 `DirAccess.make_dir_recursive_absolute(LEVELS_DIR)` 与 `(CHAPTERS_DIR)` 确保目录。
> 6. `_init` 末尾 `quit()` 会覆盖守门 `quit(1)` 的退出码 → 改用 `_exit_code` 成员变量,失败 `return`,`_init` 仅 `quit(_exit_code)` 一次;`_build_level` 失败 `return null`、`_save_chapter` 返回 `bool`,由 `_run` 统一置 `_exit_code = 1`。

- [ ] **Step 2: import(识别新增 .gd 的 class_name 与 .uid)**

Run:
```bash
"$GODOT" --headless --path . --import
```
Expected: 无错误退出;生成 `scripts/tool/generate_first_levels.gd.uid`(需在 commit 时一并 add)。

- [ ] **Step 3: 跑产关脚本**

Run:
```bash
"$GODOT" --headless --path . -s res://scripts/tool/generate_first_levels.gd
```
Expected: 打印 8 行 `产出关卡 ... -> res://resources/levels/l*.tres` + 2 行 `产出章节 ... -> res://resources/chapters/chapter_0*.tres` + `全部完成: 8 关 + 2 章`;退出码 0。若任何 `push_error` → 退出码 1,按报错修正后重跑。

- [ ] **Step 4: 跑契约测试,确认 PASS**

Run:
```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_first_levels_generated -gexit
```
Expected: PASS —— `test_all_levels_exist_with_correct_meta` / `test_chapter_refs` / `test_mechanic_levels_have_lever_and_door` 全绿。

- [ ] **Step 5: 提交脚本 + 测试 + 产物**

```bash
git add scripts/tool/generate_first_levels.gd scripts/tool/generate_first_levels.gd.uid \
        tests/tool/test_first_levels_generated.gd \
        resources/levels/l1_1.tres resources/levels/l1_2.tres resources/levels/l1_3.tres \
        resources/levels/l1_4.tres resources/levels/l1_5.tres \
        resources/levels/l2_1.tres resources/levels/l2_2.tres resources/levels/l2_3.tres \
        resources/chapters/chapter_01.tres resources/chapters/chapter_02.tres
git commit -m "$(cat <<'EOF'
feat(level): headless 产关脚本产出首批 8 关 + 2 章

generate_first_levels.gd(extends SceneTree)调 PathGenerator/Filler/Exporter
一次性产出 l1_1~l2_3 + chapter_01/02;门机关关 heuristic 全图稳定摆 lever/door;
MechanicOrderValidator + LevelSystem.validate 双重守门。test_first_levels_generated
契约测试 + test_levels_valid 自动覆盖。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 全量回归 + 端到端 QA 交付

**Files:** 无新增/改(验证 + 交付)

- [ ] **Step 1: GUT 全量回归**

Run:
```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: 全绿(原 123 + 新 `test_first_levels_generated` 3 用例)。其中 `test_levels_valid` 自动遍历 `resources/levels/*.tres`,新 8 关全部 `validate()` 无错。

- [ ] **Step 2: 提交 spec + plan(若尚未提交)**

```bash
git add docs/superpowers/specs/2026-07-12-first-levels-generation-design.md \
        docs/superpowers/plans/2026-07-13-first-levels-generation.md
git commit -m "$(cat <<'EOF'
docs(level): 首批关卡 headless 产关 spec + plan

spec:headless 产关方式/8关蓝图/守门/技术债(G1~G7 决策含理由与弃选)。
plan:TDD 三任务(契约测试→脚本产关→回归交付)。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: 端到端人工 QA(用户执行,列入交付清单)**

用户在编辑器 F5(主场景 `boot.tscn`)或命令行 `"$GODOT" --path .` 跑游戏,确认:

- [ ] 启动即选关 UI,初始仅 `1-1 初扫` 可点且 ▶ 高亮,其余灰显
- [ ] 选 `1-1` → 进入关卡可玩;扫完全覆盖 → 通关回列表,`1-1` 标 ✓,`1-2 石径` 解锁 + ▶ 高亮
- [ ] 逐关玩通至 `2-3`(跨章衔接:通关 `1-5` 解锁 `2-1`)
- [ ] 门机关关(2-1/2-2/2-3):踩机关(lever)后门(door)可通行;未踩机关时门阻挡
- [ ] HUD「返回列表」按钮可用,返回不解锁
- [ ] 难度递进体感(网格 5×5→7×7 / 障碍 / 机制逐步引入)无明显死局挫败

> QA 反馈处理:若某关需改布局/机制,改 `generate_first_levels.gd` 参数表(size/goal/gen/lever_ids)或用 `obstacle_overrides` 加瓶颈,重跑脚本覆盖 .tres,重跑 GUT 回归。设计感精雕走此循环(spec §8 技术债)。

---

## Self-Review(写完后自检)

**1. Spec coverage:**
- §3 脚本形态 → Task 2 Step 1 ✓
- §4 8 关参数表 → Task 2 脚本 `_level_def()` + Task 1 测试契约 ✓
- §5 chapter 产出(load 方案,ext_resource 引用)→ Task 2 `_save_chapter` + Task 1 `test_chapter_refs` ✓
- §6 守门(MechanicOrderValidator + LevelSystem.validate)→ Task 2 `_build_level` ✓
- §6 GUT 覆盖(test_levels_valid 自动 + test_first_levels_generated)→ Task 1 + Task 3 Step 1 ✓
- §7 产出文件清单 → Task 2 Step 5 add 列表 ✓
- §9 验收 → Task 3 ✓

**2. Placeholder scan:** 无 TBD/TODO;脚本与测试代码完整可跑;命令含 expected。`door_files` 的 `if false else` 注解已说明可简化。

**3. Type consistency:** `_level_def()` / `_def()` / `_build_level()` / `_gen_path()` / `_make_meta()` / `_make_lever_doors()` / `_save_chapter()` 命名贯穿一致;字段 `file/meta_id/display/diff/size/start/goal/gen/lever_ids` 在定义与使用处一致;`lever_ids` → `LeverData.id` + `DoorData.lever_ids=[id]` 对齐 `mechanic_data.gd`/`door_data.gd`/`lever_data.gd` 既有字段。

---

## 已知技术债(承接 spec §8)

- `random_walk` 无 seed(1-2/1-3/1-4 雷同风险),.tres 存盘固化
- 门机关关 heuristic 全空(无假山、2-3 无指定终点)→ QA 后用 `obstacle_overrides` / `random_walk(start,end)` 迭代
- 求解器(D8)本轮不碰,后续单独 brainstorm
