# 实现设计:monk 机制批次 1(机关 / 门 / 桥 / 动态水)

> **任务来源**: 可玩 MVP(逻辑层 + UI + 测试关卡,16 GUT 绿)完成后,从恢复点继续——按项目 memory「下一步」实现机制增量第一批。
> **任务内容**: 在逻辑层落地机制规范中 4 个机制(机关 / 门 / 桥 / 动态水)的 `can_pass` 规则、状态推导(路径纯函数)、计入需扫、数据校验;并给 GridRenderer 加占位表现(纯色块 + 状态高亮)。传送单独后续批次。
> **参考文档**:
> - `docs/project/2026-07-09-mechanics-spec-design.md` —— 机制规范(权威依据:§3 查询接口、§4.3-4.7 各机制、§5 需扫汇总、§7 数据校验)
> - `docs/project/2026-07-09-level-data-format-design.md` —— 关卡数据格式(mechanics 列表字段)
> - `docs/project/2026-07-09-testing-convention-design.md` —— 测试约定(逻辑层必测、严格红绿重构、每绿 commit)
> - `scripts/mechanics/mechanic_system.gd` `scripts/grid/path_state.gd` `scripts/level/level_system.gd` `scripts/ui/grid_renderer.gd` —— 现状接入点
> **生成日期**: 2026-07-09

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-09 |
| 状态 | 设计已确认(用户 brainstorm 批准),待 spec 复核 → 实施 |
| 产物路径 | `docs/project/2026-07-09-mechanics-batch1-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming(范围/顺序/分支/表现层对齐)→(用户批准)→ 本文档 → writing-plans |
| 上游 | 机制规范、关卡数据格式、测试约定、可玩 MVP 代码 |
| 下游 | writing-plans 逐步实现计划;传送批次(后续) |

## 1. 范围

**纳入**:
- 4 个机制逻辑层:`LeverData`(机关)/ `DoorData`(门)/ `BridgeData`(桥)/ `DynamicWaterData`(动态水)
- `MechanicSystem` 多态分派 + 机关状态查询(`is_lever_pressed`)
- `LevelSystem`:机关坐标映射注入、需扫格推导补全、轻量数据校验
- `GridRenderer` 占位表现(纯色块 + 状态高亮,无美术资产)
- `tests/mechanics/` GUT 覆盖(严格 TDD)

**不纳入**(传送,单独批次):`PortalData` 需改 `PathState.move` 第三层校验(强制传送约束 + 追加配对端 + 邻接豁免)与表现层,风险隔离。

## 2. 核心架构决策:`can_pass` 改多态分派

### 2.1 现状问题

当前 `MechanicSystem.can_pass` 与 `GridRenderer._cell_color` 均为 `is` 类型链。新增 4 机制后将出现**三处重复 is 链**(`can_pass` / `need_cover` / 渲染),且违反:
- 项目架构原则「新增机制不改主循环」
- 机制规范 §9「基类 + 虚方法 `_can_pass` / `_state`,实现期定」

### 2.2 方案对比

| 方案 | 描述 | 评价 |
|---|---|---|
| A. 延续 is 链 | `can_pass` 内 `if data is DoorData ...` 逐机制分支 | 改动最小;但三处重复 + 主循环随机制膨胀,违背架构原则。**不采用** |
| **B. 多态分派(采用)** | `MechanicData` 虚方法,子类 override,`MechanicSystem` 恒为 3 行 | 符合架构原则与规范 §9;新增机制只加一个 Data 子类,主循环零改动 |

### 2.3 多态契约

```gdscript
# MechanicData 基类
class_name MechanicData
extends Resource

@export var coord: Vector2i

func can_pass(_path: Array, _ms) -> bool:   # 默认可通行(机关/传送/普通格)
    return true
func counts_for_need_cover() -> bool:       # 默认计入需扫
    return true
```

```gdscript
# MechanicSystem —— 不随机制增长
func can_pass(coord: Vector2i, path: Array) -> bool:
    var data: MechanicData = data_at(coord)
    return data == null or data.can_pass(path, self)
```

各子类 override `can_pass`:
- `WallData` / `FlowingWaterData` → `return false`(永久障碍),`counts_for_need_cover` → `false`
- `LeverData` → 默认 `true`(不 override)
- `DoorData` / `BridgeData` → `return ms.is_lever_pressed(lever_ids, path)`
- `DynamicWaterData` → 相位公式(§4)

> 表现层(`GridRenderer`)仍可用 `is` 链 + path 算状态色——表现层本就与具体类型耦合,可接受;逻辑层保持多态、零 is 链。

## 3. 各机制数据定义与规则

字段、规则、状态均严格承接机制规范 §4.3-4.7;`len(P)` := path 格子数(= `path.size()`)。

### 3.1 机关 LeverData(规范 §4.4)
- 数据:`coord`, `id: String`
- `can_pass`:恒 `true`
- 状态(被踩):`coord ∈ P`
- 计入需扫:是
- 边角:机关无独立状态,被踩由 P 决定

### 3.2 门 DoorData(规范 §4.3)
- 数据:`coord`, `lever_ids: Array[String]`
- `can_pass`:`ms.is_lever_pressed(lever_ids, path)`(OR 语义,任一机关被踩即开)
- 状态(门开):`∃ id ∈ lever_ids, lever_cell(id) ∈ P`
- 计入需扫:是
- 边角:`lever_ids` 空 → 门永关;校验期拒绝空(§5)

### 3.3 桥 BridgeData(规范 §4.6)
- 数据:`coord`, `lever_ids: Array[String]`
- `can_pass`:`ms.is_lever_pressed(lever_ids, path)`(同门 OR 语义)
- 状态(铺放):`∃ id ∈ lever_ids, lever_cell(id) ∈ P`
- 计入需扫:是
- 边角:同门

### 3.4 动态水 DynamicWaterData(规范 §4.7)
- 数据:`coord`, `period: int = 4`
- 相位:`phase = len(P) mod period`(P 为踏入 coord 前的当前路径 = `path.size()`)
- 水位:`LOW ⟺ phase < ceil(period / 2)`(GDScript 整数除法实现:`phase < (period + 1) / 2`,与规范 §4.7 `(period+1)/2` 一致);LOW=落(可通行),HIGH=涨(不可通行)
- `can_pass`:`level == LOW`
- 计入需扫:是(须在 LOW 相位扫过)
- 边角:`period ≥ 2`(校验期拒绝 `< 2`)

相位分布表(落 ≥ 涨,机制规范 §4.7):

| period | LOW 相位(可通行) | HIGH 相位(不可通行) |
|---|---|---|
| 2 | 0 | 1 |
| 3 | 0, 1 | 2 |
| 4 | 0, 1 | 2, 3 |
| 5 | 0, 1, 2 | 3, 4 |

## 4. 机关状态查询(MechanicSystem)

机关坐标映射在 `LevelSystem.load` 时建立,存于 `MechanicSystem`:

```gdscript
var _lever_cells: Dictionary = {}   # id(String) -> coord(Vector2i)

func register_lever(id: String, coord: Vector2i) -> void:
    _lever_cells[id] = coord

func is_lever_pressed(lever_ids: Array, path: Array) -> bool:
    for id in lever_ids:
        var c = _lever_cells.get(id)
        if c != null and c in path:
            return true
    return false
```

> `lever_ids` 引用不存在的机关 id → `.get(id)` 返回 null → 视为未踩(安全);引用缺失由 §5 校验期拒绝。

## 5. 需扫格推导(LevelSystem.need_cover)

承接机制规范 §5:非永久障碍格全计入需扫。

```gdscript
func need_cover() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(_level.size.y):
        for x in range(_level.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = mechanic_system.data_at(coord)
            if data == null or data.counts_for_need_cover():
                result.append(coord)
    return result
```

计入:EMPTY + 门 + 机关 + 桥 + 动态水;不计:假山 / 流水。

## 6. 数据校验(轻量,机制规范 §7)

`LevelSystem._validate() -> Array[String]`(错误描述列表,空 = 有效)。`load` 时调用,非空则 `push_error` 各条并视为无效关卡。

本次覆盖(传送 `pair_id` 成对属后续批次):

| # | 校验 | 失败情形 |
|---|---|---|
| 1 | `DynamicWaterData.period ≥ 2` | `period < 2`(0 除零、1 退化静态) |
| 2 | `DoorData` / `BridgeData.lever_ids` 非空 | 空 → 门永关 / 桥永不放,格计入需扫则必无解 |
| 3 | `lever_ids` 引用的机关 id 存在 | 引用不存在的机关 |

可解性由关卡设计工具保证(规范 §7),运行时不验证。

## 7. 接入点改动清单

| 文件 | 改动 |
|---|---|
| `scripts/mechanics/mechanic_data.gd` | 加虚方法 `can_pass(path, ms)` / `counts_for_need_cover()`(默认实现) |
| `scripts/mechanics/wall_data.gd` `flowing_water_data.gd` | 空子类 → override `can_pass=false` / `counts_for_need_cover=false` |
| `scripts/mechanics/lever_data.gd`(新) | `id: String`;默认 `can_pass=true` |
| `scripts/mechanics/door_data.gd`(新) | `lever_ids: Array[String]`;`can_pass=ms.is_lever_pressed(...)` |
| `scripts/mechanics/bridge_data.gd`(新) | 同门 |
| `scripts/mechanics/dynamic_water_data.gd`(新) | `period: int=4`;相位公式 |
| `scripts/mechanics/mechanic_system.gd` | `can_pass` 改多态;新增 `_lever_cells` + `register_lever` + `is_lever_pressed` |
| `scripts/level/level_system.gd` | `load` 遍历 mechanics 注入机关 + `_validate()`;`need_cover` 走多态 |
| `scripts/ui/grid_renderer.gd` | 4 机制占位色 + 状态高亮(读 `_path_state.path` 算当前态) |
| `tests/mechanics/*.gd`(新/扩) | 机关 / 门 / 桥 / 动态水 / 校验 各规则 GUT 测试 |

> `path_state.gd`、`grid_model.gd` 本次**不动**(传送才需改 PathState)。

## 8. GridRenderer 占位表现

- 4 机制纯色块:机关=金黄、门=棕、桥=木褐、动态水=浅蓝(区别于静态流水深蓝 `COLOR_WATER`)
- 状态高亮(读 `_path_state.path`,逻辑层多态结果):
  - 门:开=亮边框 / 关=暗填充
  - 桥:铺放=实色 / 未铺=半透明
  - 动态水:当前相位 LOW=浅 / HIGH=深(若该格未扫)
- 已扫格:叠 `COLOR_SWEPT` 半透明(保留底层机制色,表示「已扫」)
- `_cell_color(coord)` → `_cell_color(coord, path)`(需当前路径算状态)

正式美术(禅意水墨)与视觉语言后续单独做。

## 9. TDD 顺序(严格红绿重构,每绿 commit)

1. **多态地基**:基类虚方法 + Wall/FlowingWater override + MechanicSystem `can_pass`/`need_cover` 改多态 → 验证:现有 16 GUT 测试仍绿(回归保护)
2. **机关**:`LeverData` + `register_lever` / `is_lever_pressed` → 验证:被踩语义测试
3. **门**:`DoorData`(OR 语义)→ 验证:开/关门测试 + 空 `lever_ids` 校验测试
4. **桥**:`BridgeData` → 验证:铺放测试(复用门逻辑)
5. **动态水**:相位公式 → 验证:period 2/3/4/5 相位表测试 + `period<2` 校验测试
6. **LevelSystem 集成**:`load` 注入机关 + `_validate()` → 验证:非法关卡校验测试
7. **GridRenderer 占位表现**:4 机制色 + 状态高亮 → 验证:手动跑游戏可见
8. **集成验证**:含机关+门+桥+动态水的测试关卡 `.tres` → 验证:GUT 全绿 + 手动跑通关

## 10. 分支与提交

- 分支 `feat/mechanics-batch1`(自 main)
- 每机制 / 每步一个 TDD commit
- 完成后合入 main;push 由用户手动(git HTTPS 经代理 TLS 握手失败,见 memory)

## 11. 验收对照

- [ ] 4 机制 `can_pass` 规则符合机制规范 §4.3-4.7
- [ ] 各机制状态均为 path `P` 纯函数(确定性;撤销零副作用)
- [ ] `MechanicSystem.can_pass` / `need_cover` 多态、无 is 链、不随机制增长
- [ ] 需扫格推导含 4 机制(规范 §5)
- [ ] 轻量校验:period≥2 / lever_ids 非空 / lever 引用存在(规范 §7)
- [ ] GUT 全绿(含回归);手动跑游戏可见 4 机制占位表现
- [ ] 未触碰 `PathState.move`(留给传送批次)

## 12. 后续

- **传送 PortalData(批次 2)**:`PathState.move` 第三层校验(强制约束 + 追加配对端 + 邻接豁免)、`pair_id` 成对校验、GridRenderer 配对连线表现
- **正式美术**:禅意水墨视觉语言(美术风格指南)
- **关卡设计工具**:`@tool` 可视化编辑 + 可解性验证(独立 spec)
