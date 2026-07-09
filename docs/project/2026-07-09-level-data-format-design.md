# 设计规范:monk 关卡数据格式

> **任务来源**: 系统架构批准后,按文档路线图(roadmap)Task 2,制定关卡数据格式——定义 `.tres` Resource 字段结构,支撑编辑器可视化编辑与批量制作(40~50+ 关)。
> **任务内容**: 定义关卡 `.tres` 的 Resource 类层次、网格表示(TileType 枚举矩阵 + 机制配置列表)、机关 ↔ 门 / 桥映射与传送配对(`lever_ids` / `pair_id`)、起终点、章节进度数据(独立 ChapterResource)、需扫格推导、编辑器可视化编辑方案、存储 → 运行时转换。
> **参考文档**:
> - `docs/project/2026-07-08-gdd-design.md` —— GDD(机制清单、胜负、状态确定性)
> - `docs/project/2026-07-08-system-architecture-design.md` —— 系统架构(机制数据驱动、MechanicSystem、GridModel)
> - `docs/superpowers/plans/2026-07-08-documentation-roadmap.md` —— 文档路线图(本任务为 Task 2)
> - `CLAUDE.md`(项目根)—— Resource / .tres、目录约定
> **生成日期**: 2026-07-09

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-09 |
| 状态 | 设计已确认,待 spec 复核 |
| 产物路径 | `docs/project/2026-07-09-level-data-format-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming →(用户复核)→ 实施 |
| 上游 | GDD、系统架构、文档路线图 Task 2 |

## 1. 背景与目标

定义关卡 `.tres` 的 Resource 字段结构,使:
- **编辑器可视化编辑**:可在 Godot inspector / `@tool` 预览中编辑关卡
- **批量制作**:字段简洁、职责清晰,支撑 40~50+ 关持续产出
- **版本管理友好**:`.tres` 为文本格式,利于 git diff
- **与架构吻合**:加载后构建 GridModel + MechanicSystem(见系统架构 §4)

## 2. 关键决策摘要

| # | 决策点 | 决策 |
|---|---|---|
| ① | 网格表示 | TileType 枚举二维矩阵(基础地形)+ 机制配置列表(复杂机制) |
| ② | 机制映射 | 门 / 桥引用机关 `id`(`lever_ids`);传送用 `pair_id`;OR 语义(任一机关被踩即开) |
| — | 章节进度 | 独立 `ChapterResource`,不混入关卡 `.tres` |
| — | 需扫格 | 运行时推导,不在 `.tres` 冗余存储 |
| — | 可视化编辑 | `@export` 暴露字段 + 可选 `@tool` 预览 |
| — | 可选终点 | `goal` 用哨兵 `Vector2i(-1,-1)` 表示「不限终点」 |

## 3. Resource 类层次

```
LevelResource (单关 .tres)
├─ size: Vector2i
├─ tiles: Array[Array[TileType]]      # 基础地形枚举矩阵
├─ mechanics: Array[MechanicData]      # 复杂机制配置列表(多态)
├─ start: Vector2i                     # 起点(必)
├─ goal: Vector2i                      # 可选终点((-1,-1)= 不限)
└─ meta: LevelMeta                     # id / 显示名 / 难度

MechanicData (Resource 基类)
├─ coord: Vector2i
└─ 子类:
   ├─ DoorData          lever_ids: Array[String]
   ├─ LeverData         id: String
   ├─ PortalData        pair_id: String
   ├─ BridgeData        lever_ids: Array[String]
   └─ DynamicWaterData  period: int

ChapterResource (章节,独立于关卡 .tres)
├─ id / display_name
├─ main_levels: Array[LevelResource]   # 主线关卡顺序
├─ branches: Array[BranchEntry]        # 可选分支 / 隐藏关
└─ unlock_condition
```

## 4. 网格表示(TileType 枚举矩阵)〔决策①〕

基础地形(空地 / 假山 / 流水)用 `TileType` 枚举二维矩阵,轻量;编辑器里像画地图。动态水**不**用枚举(有 `period` 参数),归 `mechanics` 列表。

```gdscript
class_name LevelResource
extends Resource

enum TileType { EMPTY, WALL, FLOWING_WATER }

@export var size: Vector2i
@export var tiles: Array[Array[int]]          # int 为 TileType 枚举值
@export var mechanics: Array[MechanicData]
@export var start: Vector2i
@export var goal: Vector2i = Vector2i(-1, -1)  # (-1,-1) = 不限终点
@export var meta: LevelMeta
```

> `tiles` 用 `Array[Array[int]]`(Godot 类型化数组不支持自定义 enum 类型,int 承载 TileType 枚举值)。

## 5. 机制配置(mechanics 列表)〔决策①②〕

`mechanics: Array[MechanicData]`,每条带 `coord` + 子类字段:

```gdscript
class_name MechanicData
extends Resource

@export var coord: Vector2i


class_name DoorData
extends MechanicData

@export var lever_ids: Array[String]


class_name LeverData
extends MechanicData

@export var id: String


class_name PortalData
extends MechanicData

@export var pair_id: String


class_name BridgeData
extends MechanicData

@export var lever_ids: Array[String]


class_name DynamicWaterData
extends MechanicData

@export var period: int
```

> 以上各 `MechanicData` 子类为**独立 `.gd` 文件**(`scripts/mechanics/`);此处并列仅展示字段结构。

| 机制 | Resource | 字段 | 计入需扫 | 说明 |
|---|---|---|---|---|
| 门 | `DoorData` | coord, lever_ids | 是 | lever_ids 引用机关 id;OR 语义 |
| 机关 | `LeverData` | coord, id | 是 | id 供门 / 桥引用 |
| 传送门 | `PortalData` | coord, pair_id | 是 | 同 pair_id 的两个成对 |
| 桥 | `BridgeData` | coord, lever_ids | 是 | lever_ids 引用机关 id |
| 动态水 | `DynamicWaterData` | coord, period | 是 | 水位 = len(path) mod period |

## 6. 映射与配对〔决策②〕

- **机关 ↔ 门 / 桥**:门 / 桥的 `lever_ids` 引用机关 `LeverData.id`;**OR 语义**——`lever_ids` 中任一机关被踩(在 path 上)即开 / 铺放
- **传送对**:两个 `PortalData` 共享同一 `pair_id` 即成对(A ↔ B)
- **假山 / 流水**:由 `TileType` 枚举表达(`WALL` / `FLOWING_WATER`),无需额外配置

## 7. 起点与终点

- `start: Vector2i`(必,玩家初始格)
- `goal: Vector2i`(可选;`Vector2i(-1,-1)` = 不限终点,胜利仅需覆盖需扫格)

## 8. 章节与进度数据(独立 ChapterResource)〔决策—〕

关卡 `.tres` 只管单关内容;章节组织在独立 `ChapterResource`(不混入关卡):

```gdscript
class_name ChapterResource
extends Resource

@export var id: String
@export var display_name: String
@export var main_levels: Array[LevelResource]   # 主线顺序
@export var branches: Array[BranchEntry]         # 可选分支 / 隐藏关
@export var unlock_condition: Resource           # 章节解锁条件(细化留实现期)
```

- 支撑 GDD §8.2 章节化(40~50+ 关按章节组织)
- `BranchEntry`:分支 / 隐藏关条目(关卡引用 + 触发条件),结构细化留实现期
- **运行时进度**(`SaveSystem`,autoload):已通关关卡 id 集合、已解锁章节,独立存档于 `user://`,不写入 `.tres`

## 9. 需扫格的推导〔决策—〕

- **运行时推导**(`LevelSystem.load` 时):需扫格 = 所有「非永久障碍」格 = `EMPTY` 格 + 所有机制格(门 / 机关 / 传送 / 桥 / 动态水)
- 不在 `.tres` 冗余存储需扫集合(避免数据不一致)
- `WALL` / `FLOWING_WATER` 不计入

## 10. 存储 → 运行时转换(LevelSystem.load)

`LevelSystem.load(level: LevelResource)` 流程:
1. 读 `size`,构建 GridModel
2. 遍历 `tiles` 矩阵:`EMPTY`→可通行格,`WALL`→构造 `WallData`,`FLOWING_WATER`→构造 `FlowingWaterData`
3. 遍历 `mechanics` 列表:构造对应 `MechanicData`(门 / 机关 / 传送 / 桥 / 动态水),按 `coord` 注册到 GridModel 该格
4. 推导需扫格集合(§9)
5. 设 `start`、`goal`

运行时 `GridModel.mechanic_data_at(coord)` 返回该格的 `MechanicData`(基础障碍由 `tiles` 推导,复杂机制由 `mechanics` 注册)——与系统架构 §4.1 / §4.2 吻合。

## 11. 编辑器可视化编辑〔决策—〕

- **@export 暴露字段**:`size` / `start` / `goal` / `tiles` / `mechanics` 在 inspector 可编辑
- **mechanics 多态数组**:`@export var mechanics: Array[MechanicData]`,inspector 可添加 / 编辑各子类实例
- **@tool 预览脚本(可选)**:在编辑器内可视化渲染网格(格子、机制位置),辅助设计;进阶,原型期可选

## 12. 验收对照

- [x] 字段覆盖 GDD 全部机制(假山 / 流水 = TileType 枚举;门 / 机关 / 传送 / 桥 / 动态水 = mechanics 配置)
- [x] 与架构 MechanicSystem 吻合(运行时每格可查 MechanicData,见 §10)
- [x] `.tres` 文本格式,可 git diff
- [x] 可视化编辑(@export + @tool)
- [x] 章节化组织(独立 ChapterResource,支撑 40~50+ 关)

## 13. 后续 / 开放问题

- `BranchEntry` / `unlock_condition` 的具体结构(章节进度细化,实现期定)
- `tiles` 矩阵在 inspector 的编辑体验(`Array[Array[int]]` 原生体验一般,可能需自定义 inspector 或 `@tool` 网格编辑器)
- 机制不可达导致关卡无解的校验(关卡设计期工具,见机制规范 / 测试约定)
- 多机关 AND 语义(当前 OR;若未来关卡需要 AND,扩展 `lever_mode` 字段)
- `SaveSystem` 存档格式细节(实现期定)
