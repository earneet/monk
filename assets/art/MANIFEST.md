# 美术资源清单

## temple/ —— 寺院庭院切片（2026-10-23，当前游戏主风格）

源图 `raw/texture/Gemini_Generated_Image_42wjkx42wjkx42wj.jpg`（2752×1536，
Gemini 生成，二选一取细节更优者；另一张 bnaq5w 弃用）。全部由
`python tools/dev/slice_temple.py` 切分产出，游戏单格 72px（原画石板
间距 ~92px，等比 92→72 缩放）：

- `atlas_floor.png`（288×288，4×4 块 72px 单板）：逐格指定 16 块干净
  石板（中央步道东西两侧，沿板缝线切，含水平翻转），可无缝平铺。
- 道具 PNG：人工指定裁切框；`*` 标记为洪泛去底（地面色族判定），
  其余为矩形裁切（内嵌原画地面）。全部补边到 72 整数倍画布、
  底边居中锚定，供 TileSet 多格 tile 使用：
  pond / rockery / tree_cherry_a·b·c* / tree_pine_a·b* / lantern_w*·e* /
  burner* / stairs / dock / gate* / wall_south / wall_west / wall_east /
  hall_main* / hall_side_l* / hall_side_r* / path / stream_strip
- `temple_tileset.tres`：由 `godot --headless -s
  res://tools/dev/build_temple_tileset.gd` 生成——source 0 = 地板 16 单格
  tile，source 1..N = 每道具一张图集源（整体一个多格 tile），
  source N+1 = `atlas_scene.png`（整幅原画 2160×1224 按 72px 格切成
  30×17 单格 tile）。
- `tests/visual/temple_stage.tscn`：**场景图块 1:1 复原整幅原画**
  （30×17 格，相邻格像素连续、零接缝），`tests/visual/tileset_probe.tscn`
  截图验收。已知约束：**多格 tile 原点必须非负**（负原点渲染被截，
  实测 Godot 4.7）。
- 周期/水体图块（原生 1:1，供 grid_renderer 平铺，禁止运行时拉伸）：
  `wall_h`（南墙一柱距 138px，墙不是整格周期 → 原生平铺+边界裁剪）、
  `wall_v`（西墙内面）、`pond_t/b/l/r`（池缘四向 72px）、
  `water`（池心净水）、`corner_tl/tr/bl/br`（净水+两向缘石合成）、
  `stream_narrow/_v`（窄渠道）。

## 游戏内 tiles/（grid_renderer 零拉伸约定）

`floor.png` = 288×288（4×4 块 72px 单板，FLOOR_TILE=72，逐格 1:1 镜像采样）；
`wall_h/wall_v` 按合并矩形原生平铺裁剪（横用 h、竖用 v）；`pond_*`/`water`/
`corner_*` 按池塘合并矩形 9-slice（不足 2×2 格时整池 `pond.png` contain-fit）；
`stream_narrow/_v` + `pond_t/b/l/r/water` 按溪流走向逐格铺；
lever/door/bridge/portal 逐格 contain-fit（等比居中，不变形）。
portal / door / bridge / swept 仍为旧水墨版素材。

## comfy 生成 —— 旧水墨风（v1，部分仍在线）

全部由 `tools/comfy` 工具链生成（ComfyUI qwen-image-2512 Q4，禅意水墨句式），
批内多候选人工筛选后落盘。复现：`python tools/comfy/comfy.py run qwen --set
"prompt=<prompt>" --set seed=<seed> ...`（batch 生成时批内序号不可精确复现，
重跑同 seed 出同风格新候选）。后处理记录：

- 绿幕去背：`tools/comfy/chroma_key.py`（角色帧/假山/池塘/法阵；walk 帧需
  `--key-all-green` 清封闭绿残片）
- 地板/机关贴图光照平坦化（除以低频高斯场）+ 亮度对齐路面均值
- lever/door/bridge 边缘 10px 羽化融入路面
- 动画帧表切片后按 bbox 底部居中对齐，消除帧间抖动

仍在使用：player/frames 全部、background/bg_temple.png、ui/icon.png、
tiles/portal.png、tiles/door.png、tiles/bridge.png、tiles/swept.png。
已被 temple/ 覆盖的旧版：floor、wall_0/1/2、stream、pond、lever
（git 历史可查）。

## 角色 player/frames/

| 文件 | 来源 | 内容 | seed |
|---|---|---|---|
| idle_0/1.png | b8 idle_sheet2 #2 | 扛帚闭目呼吸 2 帧（1.8fps） | 2464461847 |
| walk_0..3.png | b8 walk_sheet2 #1 | 扛帚行走循环 4 帧（6fps，左右向翻转） | 3564296787 |

## 背景 / UI

| 文件 | 来源 | 内容 | seed |
|---|---|---|---|
| background/bg_temple.png | b3 #1 | 水墨山水（菜单与关卡背景） | 1333870229 |
| ui/icon.png | b5 #2 | 墨圈小和尚项目图标（绿幕去背） | 4063825168 |

风格句式骨架与候选审查流程见 `.agents/skills/gen-asset/SKILL.md`。
