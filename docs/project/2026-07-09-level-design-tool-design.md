# 设计规范:monk 关卡设计工具

> **任务来源**: 机制规范 §9 提及「关卡设计工具(用户规划)」保证关卡可解 + 机制配置有效。本工具贯彻用户提出的「路径优先」关卡设计法,在 Godot 编辑器内提供可视化设计环境,产出游戏可直接加载的关卡。
> **任务内容**: 定义关卡设计工具的路径优先法、工作数据结构(WorkLevelResource)、设计流程、工具形态(Godot @tool)、路径输入、机制标注与校验、空白处理、输出(工作格式 + 导出)、校验清单。
> **参考文档**:
> - `docs/project/2026-07-08-gdd-design.md` —— GDD(机制、胜负、确定性)
> - `docs/project/2026-07-08-system-architecture-design.md` —— 系统架构(机制数据驱动)
> - `docs/project/2026-07-09-level-data-format-design.md` —— 关卡数据格式(LevelResource,运行格式)
> - `docs/project/2026-07-09-mechanics-spec-design.md` —— 机制规范(§7 数据校验、各机制规则)
> - `docs/superpowers/plans/2026-07-08-documentation-roadmap.md` —— 文档路线图
> **生成日期**: 2026-07-09

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-09 |
| 状态 | 设计已确认,待 spec 复核 |
| 产物路径 | `docs/project/2026-07-09-level-design-tool-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming(路径优先法深度讨论)→(用户复核)→ 实施 |
| 上游 | GDD、系统架构、关卡数据格式、机制规范 |

## 1. 背景与目标

哈密顿路径的可解性极难从布局反推保证。本工具贯彻**路径优先法**:设计者先画通关路径(即「解」),路径外智能填充障碍,「抠」出关卡——**天然保证可解**(路径本身就是解)。工具在 Godot 编辑器内运行,产出游戏可直接加载的 `LevelResource`。

## 2. 关键决策摘要

| # | 决策点 | 决策 |
|---|---|---|
| LD1 | 空白处理 | 智能填充(假山 + 流水组合)打底 + 人工标注 / 方便修改 |
| LD2 | 机制融入 | 画路径时标注机制格 + 依赖,工具校验自洽 |
| LD3 | 工具形态 | Godot 编辑器内 `@tool`(自定义网格画布视图) |
| LD4 | 路径输入 | 逐格点击 + 拖拽(手画)+ 自动随机生成 |
| LD5 | 输出架构 | 工作格式 `WorkLevelResource`(`.tres`,含 path)+ 导出器 → `LevelResource`(`.tres`,运行) |
| — | 智能填充规则 | 默认:边界假山 + 内部流水(`fill_rule` 可扩展其他策略) |
| — | 工具范围 | 单关 `WorkLevelResource` 编辑 + 元数据;章节级批量管理列后续 |

## 3. 路径优先法(核心方法论)

1. 设计者画一条**通关路径**(满足胜利条件的哈密顿路径:覆盖所有可通行格 + 可选终点)
2. 路径上的格 = **可通行格 / 需扫格**;起点 = `path[0]`,可选终点 = `path[-1]`
3. 路径外「空白区域」= 智能填充障碍(假山 / 流水),「抠」出关卡形状
4. **天然可解**:路径即解,工具无需求解哈密顿路径(NP 难)

> 设计者主动设计「解」,而非从布局反推——这是路径优先法的精髓,直接绕开可解性难题。

## 4. 工作数据结构(WorkLevelResource)

工作格式是工具的「源」,含 LevelResource 没有的 **`path`**(设计期数据):

```gdscript
class_name WorkLevelResource
extends Resource

enum FillRule { BORDER_WALL_INNER_WATER }   # 默认;后续可扩展 ALL_WALL / BY_REGION

@export var meta: LevelMeta                  # id / display_name / difficulty
@export var chapter_id: String               # 章节归属(可选)
@export var size: Vector2i
@export var path: Array[Vector2i]            # ★ 有序通关路径(核心;LevelResource 没有)
@export var has_goal: bool                   # path[-1] 是否为指定终点
@export var mechanics: Array[MechanicData]   # 路径上的机制(与 LevelResource.mechanics 同构)
@export var fill_rule: FillRule              # 智能填充策略(默认 BORDER_WALL_INNER_WATER)
@export var obstacle_overrides: Dictionary   # Vector2i(var) -> "WALL"/"FLOWING_WATER" 手动覆盖
@export var notes: String                    # 设计注释(可选)
@export var version: int                     # 工作格式版本
```

**与 LevelResource 的差异**:多了 `path`、`fill_rule` + `obstacle_overrides`(填充策略)、`chapter_id`、设计注释;运行格式只要 `tiles` 矩阵 + `mechanics` + `start`/`goal`。

## 5. 设计流程

1. **设网格尺寸** `size`
2. **画路径**(逐格点击 / 拖拽)—— 定义可通行格 + 顺序 + 起点 + 可选终点
3. **标注机制**(对路径上某格设门 / 机关 / 传送 / 桥 / 动态水 + 依赖)
4. **智能填充空白**(路径外,按 `fill_rule`)
5. **人工微调**(逐格改障碍类型、调机制,记入 `obstacle_overrides`)
6. **工具校验**(路径有效 + 机制自洽)
7. **导出** `LevelResource.tres`

## 6. 工具形态〔LD3〕

- **Godot 编辑器内 `@tool`**,作为编辑器插件(`addons/level_designer/`,游戏导出不包含)
- 自定义编辑器视图:网格画布(`Control`/`Node2D` + `@tool` 脚本),画路径、标机制、实时预览
- 复用 Godot 编辑器(inspector 编辑 `WorkLevelResource` 字段、面板)
- 读写 `WorkLevelResource.tres`(ResourceSaver/Loader,原生)

## 7. 路径输入〔LD4〕

路径有三种产生方式:
- **逐格点击(手画)**:点击顺序 = 路径顺序;工具实时校验**正交邻接** + **不重复**
- **拖拽(手画)**:按下拖拽,经过格连成路径(快速模式)
- **自动随机生成**:程序在你指定的可通行区域(整个网格或框选子区域)内,生成一条覆盖该区域的哈密顿路径作起点;你再调整 / 标机制

通用:
- 起点 = 第一格;终点可选(末格标 `has_goal = true`)
- 撤销 / 重做路径编辑(适用于手画与自动生成后的调整)

## 8. 机制标注 + 校验〔LD2〕

设计者对路径上某格设机制类型 + 依赖(同 LevelResource:`DoorData.lever_ids` / `LeverData.id` / `PortalData.pair_id` / `BridgeData.lever_ids` / `DynamicWaterData.period`)。工具校验(机制规范 + 路径顺序):

- **机关先于其控制的门 / 桥经过**(否则门 / 桥未开启,过不去)
- **传送配对完整**(同 `pair_id` 恰 2 个;路径中 A 后接 B 为传送步)
- **动态水**:路径经过动态水格时水位为 LOW(`len(P) mod period`,机制规范 §4.7)
- `lever_ids` 引用存在 / 非空;`period ≥ 2`

## 9. 空白处理〔LD1〕

- **智能填充(默认 `BORDER_WALL_INNER_WATER`)**:路径外格——邻关卡外边界 → 假山 `WALL`(围墙);被路径包围的内部空白 → 流水 `FLOWING_WATER`(水景)。贴合寺院主题
- **人工标注 / 修改**:逐格改障碍(假山 ↔ 流水 ↔ 空),记入 `obstacle_overrides`
- **导出时合成**:路径外格,若在 `obstacle_overrides` 则用其值,否则按 `fill_rule` 默认
- 路径外全是障碍(假山 / 流水),保证路径覆盖全部可通行格(可解)
- `fill_rule` 可扩展其他策略(`ALL_WALL` / `BY_REGION` 等,后续)

## 10. 输出(工作格式 + 导出)〔LD5〕

- **工作格式(源)**:`WorkLevelResource.tres`(含 path + 机制 + 填充 + 元数据),`@tool` 原生编辑
- **导出器**:`WorkLevelResource` → `LevelResource.tres`
  - `path` → `tiles` 矩阵(路径格 = `EMPTY`;路径外按 `obstacle_overrides` / `fill_rule` = `WALL`/`FLOWING_WATER`)
  - `path[0]` → `start`;`has_goal` → `goal`(`path[-1]` 或 `(-1,-1)` 不限)
  - `mechanics` → 直传
  - `meta` → 提取(id / 名 / 难度)
- **游戏** `LevelSystem.load` 加载 `LevelResource.tres`(与数据格式吻合)
- **可迭代**:改工作格式,随时重新导出 `.tres`(Godot 升级 / 字段调整,从源重新生成)

## 11. 校验清单(工具保证,对应机制规范 §7)

- [ ] 路径有效:正交邻接、不重复、覆盖所有可通行格(= 路径本身)
- [ ] 机制自洽:机关先于门 / 桥、传送配对、动态水低水位经过、`lever_ids` 有效、`period ≥ 2`
- [ ] 可解:路径本身就是解(覆盖需扫格 + 可选终点)
- [ ] 数据有效:`LevelResource` 字段完整(导出后校验)

## 12. 验收

- [ ] 路径优先流程完整(画 → 标 → 填 → 调 → 校验 → 导出)
- [ ] 工作数据结构含 `path`(LevelResource 没有)
- [ ] 机制融入清晰(标注 + 校验,机关先于门等)
- [ ] 输出 `LevelResource.tres` 游戏直接加载
- [ ] 校验覆盖机制规范 §7

## 13. 后续 / 开放问题

- `FillRule` 其他策略实现(`ALL_WALL` / `BY_REGION` 按连通区域分类)
- 章节级批量管理(多关 `WorkLevelResource` 组织成 `ChapterResource`,见数据格式 §8)
- `WorkLevelResource` 的 inspector 自定义(更友好的机制编辑 UI)
- 工具与 `LevelSystem.load` 的运行时校验对接(工具校验 vs 运行时校验的边界)
- 路径编辑的辅助(如显示「已扫格」高亮、机制依赖可视化连线)
- 自动生成的哈密顿路径算法选型(网格结构化生成:螺旋 / 分形 / 启发式)
