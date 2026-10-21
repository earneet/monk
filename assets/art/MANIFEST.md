# 美术资源清单

全部由 `tools/comfy` 工具链生成（ComfyUI qwen-image-2512 Q4，禅意水墨句式），
批内多候选人工筛选后落盘。复现：`python tools/comfy/comfy.py run qwen --set
"prompt=<prompt>" --set seed=<seed> ...`（batch 生成时批内序号不可精确复现，
重跑同 seed 出同风格新候选）。后处理记录：

- 绿幕去背：`tools/comfy/chroma_key.py`（角色帧/假山/池塘/法阵；walk 帧需
  `--key-all-green` 清封闭绿残片）
- 地板/机关贴图光照平坦化（除以低频高斯场）+ 亮度对齐路面均值
- lever/door/bridge 边缘 10px 羽化融入路面
- 动画帧表切片后按 bbox 底部居中对齐，消除帧间抖动

## 瓦片 tiles/

| 文件 | 来源 | 内容 | seed |
|---|---|---|---|
| floor.png | b4 #2 | 浅灰青石板（整板逐格 1:1 镜像采样） | 1333870229→b4 见下 |
| wall_0/1/2.png | b7 #1/#2/#3 | 假山石群三变体（绿幕去背，贪心合并块按哈希选型） | 1187435399 |
| stream.png | b7 #2 | 带石岸溪流段（横竖向自适应旋转，饱和 +1.45） | 658084625 |
| pond.png | b7 #2 | 石缘圆池塘（绿幕去背，动态水涨落 tint） | 3339407632 |
| portal.png | b9 #1 | 圆形法阵石盘（绿幕去背） | 754727443 |
| lever.png | b1 #2 提亮羽化 | 青铜机关踏板 | 1953390008 |
| door.png | b1 #2 提亮羽化 | 红漆木门（关暗/开亮） | 2398401684 |
| bridge.png | b2 #2 裁切提亮羽化 | 木桥面（搭好亮/未搭暗） | 1865748924 |
| swept.png | b3 #2 | 枯山水砂纹（55% alpha 扫过层） | 3370144045 |

floor 实际源：b4 floor 批 seed=4255015826 的 #2（qwen_00201_）。

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
