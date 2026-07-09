# 设计规范:monk 测试约定

> **任务来源**: 系统架构批准后,按文档路线图(roadmap)Task 4,制定测试约定——确立 TDD 流程与测试结构,确保状态确定性原则与各机制规则可被测试覆盖。
> **任务内容**: 选定测试框架(GUT)、测试目录结构、严格 TDD 流程、测试范围(逻辑层必测 / 表现层可选)、关键测试场景、运行方式。
> **参考文档**:
> - `docs/project/2026-07-08-gdd-design.md` —— GDD(§4 状态确定性原则)
> - `docs/project/2026-07-08-system-architecture-design.md` —— 系统架构(§4 模块、§9 确定性落地;逻辑层可独立测试)
> - `docs/project/2026-07-09-mechanics-spec-design.md` —— 机制规范(§7 数据校验、各机制规则)
> - `docs/project/2026-07-09-level-data-format-design.md` —— 关卡数据格式
> - `docs/superpowers/plans/2026-07-08-documentation-roadmap.md` —— 文档路线图(本任务为 Task 4)
> **生成日期**: 2026-07-09

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-09 |
| 状态 | 设计已确认,待 spec 复核 |
| 产物路径 | `docs/project/2026-07-09-testing-convention-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming →(用户复核)→ 实施 |
| 上游 | GDD、系统架构、机制规范、关卡数据格式、文档路线图 Task 4 |

## 1. 背景与目标

系统架构(§3)将逻辑层(GridModel / MechanicSystem / PathState / LevelSystem)设计为**纯 GDScript、无节点依赖**,正是为了可被单元测试。本约定确立测试框架、目录、TDD 流程与关键测试场景,确保:
- **状态确定性原则**(GDD §4)可被测试覆盖(撤销回滚测试)
- 各机制规则(机制规范)有权威验证
- 关卡数据校验(机制规范 §7)可自动化

## 2. 关键决策摘要

| # | 决策点 | 决策 |
|---|---|---|
| ① | TDD 严格度 | **严格红绿重构**(每功能先写失败测试 → 实现 → 重构) |
| — | 测试框架 | GUT(Godot Unit Test,`addons/gut`) |
| — | 测试目录 | 镜像 `scripts/` 子系统结构 |
| — | 测试范围 | 逻辑层**必测**;InputSystem 归一逻辑**可测**;UI 表现层**不强制**单元测 |

## 3. 框架选型

- **GUT**(Godot Unit Test):Godot 生态主流单元测试插件
- 安装:Godot 资产库 或 git submodule,置于 `addons/gut/`
- 项目启用:在 `project.godot` 启用 GUT 插件(资产库安装后自动注册)

## 4. 测试目录结构(镜像 `scripts/`)

```
tests/
├── grid/            # GridModel、PathState
├── mechanics/       # MechanicSystem 各机制规则
├── level/           # LevelSystem
└── gut_config.ini   # GUT 配置(测试目录、运行参数)
```

镜像 `scripts/` 子系统(`grid/` / `mechanics/` / `level/`),测试与被测代码位置对应,易查找。

## 5. TDD 流程(严格,红绿重构)〔决策①〕

每个功能 / bug 修复遵循:
1. **红**:写一个**失败**的测试,精确描述期望行为
2. **绿**:写**最小**的实现使测试通过(不强求完美)
3. **重构**:优化实现(命名、结构、去重),测试仍绿
4. **频繁 commit**:每「绿」一次即提交

GUT 测试风格:
```gdscript
extends GutTest

func test_door_opens_when_lever_in_path():
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    var path: Array[Vector2i] = [Vector2i(0, 0)]   # 假设机关 L1 在 (0,0)
    assert_true(DoorRule.is_open(door, path), "机关在路径上时门应开启")
```

## 6. 测试范围

- **必测**(逻辑层,纯 GDScript 无节点依赖):
  - `GridModel`、`MechanicSystem`、`PathState`、`LevelSystem`
  - 数据校验(机制规范 §7)
- **可测**(若归一逻辑可分离为纯函数):
  - `InputSystem` 的「输入 → 移动意图坐标」归一(桌面键盘 / 移动点击 → 目标格)
- **不强制单元测**(节点依赖,表现层):
  - `UI`(渲染、HUD、菜单)——靠手动 / 集成验证;若逻辑与表现严格分离(架构 §3),UI 几乎不含可测逻辑

## 7. 关键测试场景(对应架构模块)

- **GridModel**:邻接查询(`neighbors`)、边界(`in_bounds`)、`mechanic_data_at`
- **MechanicSystem**:各机制 `can_pass` / `state`
  - 门:OR 语义(`lever_ids` 任一在 path 即开)
  - 桥:同门(铺放)
  - 传送:强制传送约束(踏入 X 后下一步必须配对 Y)
  - 动态水:水位公式 `LOW ⟺ (len(P) mod period) < (period+1)/2`(机制规范 §4.7 相位表)
  - 机关:被踩 ⟺ `coord ∈ P`
- **PathState**:
  - `move` 三层校验(不重复 / `can_pass` / 传送强制)
  - **`undo` 确定性回滚**(核心):走若干步 → 记录派生状态 → `undo` → 验证门 / 桥 / 水位正确回滚
  - `is_covered`(覆盖判定)
- **LevelSystem**:
  - `load`(tiles 枚举 + mechanics 列表 → GridModel + MechanicSystem)
  - `check_win`(覆盖需扫格 + 可选终点)
  - 需扫格推导(非永久障碍格)
- **数据校验**(机制规范 §7):
  - `period ≥ 2`、`lever_ids` 非空、`pair_id` 成对、`lever_ids` 引用存在

## 8. 运行测试

- **编辑器**:GUT 测试面板(可视化选 / 跑测试)
- **命令行**:
```bash
godot --path . -s res://addons/gut/gut_cmdln.gd -gconfig=tests/gut_config.ini
```
> 具体语法随 GUT 版本;`gut_config.ini` 配置测试目录与参数。

## 9. 验收对照

- [x] 明确「测什么 / 怎么测 / 目录在哪 / 如何运行」
- [x] 确定性原则(GDD §4)可被测试覆盖(`undo` 回滚测试)
- [x] 与架构模块边界对应(逻辑层必测)
- [x] 数据校验(机制规范 §7)可自动化

## 10. 后续 / 开放问题

- GUT 具体版本与 API 细节(实现期安装时确定)
- CI 集成(命令行跑测试 + 回归)——待项目接入 CI 时定
- 关卡可解性自动验证(机制规范 §7 / §9 关卡设计工具负责;测试约定提供数据校验测试,可解性算法留关卡设计工具)
- UI 自动化测试(若后续需要,引入基于图像 / 输入回放的工具)
