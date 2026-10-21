---
name: gen-asset
description: 调用 ComfyUI 服务器生成游戏美术资源（瓦片贴图、小和尚 sprite、UI 图标、背景立绘），自动出多张候选、看图自检迭代、按规范落盘到 assets/art/。Use when 用户要生成图片/出图/图标/icon/sprite/贴图/瓦片/立绘/背景/美术资源，或提到 ComfyUI；明确点名 gpt image2/image2.5 生图时走 GPT Image 网关通道。
---

# gen-asset — 游戏资源生成

## 通道选路

- **默认走 ComfyUI**（`python tools/comfy/comfy.py`，纯 stdlib）。服务器地址看 `tools/comfy/config.json` 的 `comfyui.url`（首次使用复制 `config.example.json` 为 `config.json`，真实配置不入库），可用 `--url` 或环境变量 `COMFY_URL` 覆盖。
- **仅当用户明确说"用 image2 / image2.5 生图"** 时才走 GPT Image 网关通道（`python tools/comfy/gptimg.py`，OpenAI Images API）。用户没点名就别用。

## 模板与选型

服务器：RTX 4090，ComfyUI 0.34.0（地址在 `tools/comfy/config.json`）。现有模板（`comfy.py workflows` 列出）：

- `qwen` —— qwen-image-2512 Q4：约 9s/张，快，批量出候选首选
- `flux2` —— flux2-dev-turbo Q4：约 33s/张，细节质量更高，定稿重跑用
- `qwen_pixel` —— qwen + 像素风 LoRA：约 40s/张（20 步/cfg=2），像素美术需求用；模板已自动加 `Pixel Art` 触发词前缀（prompt 里不要重复写），负向提示词生效且已含文字排除项

`qwen`/`flux2` 为 turbo 档（8 步、cfg=1），负向提示词不生效；`qwen_pixel` 的负向提示词生效。资源类型（瓦片/sprite/图标/背景）**不换模板**，靠 prompt 措辞 + width/height 区分。要接新模型/LoRA 时从 ComfyUI 导出 API 格式 JSON（设置 → Enable Dev Mode Options → Save (API Format)）放进 `tools/comfy/workflows/`，占位符改法见该目录 README.md。

出图如需像素风后处理（AI 原生都是渐变/低保真风），用 `tools/comfy/pixel_quantize.py`（降采样 + 限定调色板量化，依赖 PIL/numpy）。

## 透明底（sprite/图标）

服务器端 RemBG **不可用**：内置 `LoadBackgroundRemovalModel` 的模型目录为空且不支持按需下载（2026-10-21 实测）。透明底走绿幕方案：

1. prompt 末尾加「纯绿色纯色背景，色值00FF00，背景完全平坦无纹理无阴影无渐变」
2. 本地去背：`python tools/comfy/chroma_key.py in.png out.png [--tol 60] [--trim 12] [--out-size 512]`
   （边缘 flood-fill 只清与边连通的绿；自动去绿溢色 + alpha 羽化；--trim 裁到内容）

实测 qwen 对绿幕遵从度很高（monk sprite、圆形图标均一次成功）。

## 标准闭环

1. **确认语义**：瓦片/机制类先读 `scripts/mechanics/` 对应机制与 `resources/levels/` 现有关卡，确认物件的中文名与行为语义，写进 prompt（如"流水障碍瓦片，水面波纹"）；sprite/图标先看目标目录现有图的尺寸和风格，保持一致
2. **批量出候选**：`--count 3` 以上、落盘到临时目录（如 `tools/comfy/out/`），不直接进 assets
3. **看图自检**：Read 图片得到 CDN 链接，再用 `mcp__4_5v_mcp__analyze_image` 逐张审查（构图、风格一致性、文字乱码、肢体错误）；也可把链接发给用户人工确认
4. **迭代**：不合格则调整 prompt（加风格锚定词、负向提示词排杂念）重跑；同一系列资源用相同 seed 微调可保持构图
5. **落盘**：选定一张按下方约定存入 `assets/art/`，把回复里记录 seed 便于复现
6. **提醒**：新文件需 Godot 编辑器打开后才会生成 .import；sprite 引用前确认已 import

## 命令速查

```bash
python tools/comfy/comfy.py run qwen --set "prompt=流水障碍瓦片，正俯视视角，游戏贴图" \
  --set width=1024 --set height=1024 --count 3 --out tools/comfy/out/water
```

- 占位符/参数以 `comfy.py workflows` 列出的为准
- 单次生成常超 2 分钟：Bash 调用要设足够 timeout（≥ --timeout 值）
- 固定 seed 用 `--set seed=42`；缺省每次自动随机
- 需要去背/放大：在 ComfyUI 模板里加 RemBg / Upscale 节点，别在本地后处理

## prompt 句式骨架（风格锚定）

同系列资源必须用同一句式骨架，只替换 `<>` 槽位——措辞漂移会导致风格漂移：

| 资源 | 句式骨架 |
|---|---|
| 瓦片贴图 | `<材质/物件描述>，铺满整个画面，无建筑物，无杂物，禅意水墨风格，正俯视90度俯视角，柔和宣纸色调，边缘干净，无文字，无印章，无水印，高清游戏贴图`（monk 实测定稿；「庭院/桥」这类词会引出建筑透视构图，纯纹理词才安全） |
| sprite | `可爱Q版<角色>，<外观描述>，正面站立全身像，居中构图，纯绿色纯色背景，色值00FF00，背景完全平坦无纹理无阴影无渐变，禅意水墨风格，无文字，无印章，无水印`（出图后 chroma_key.py 去背） |
| 图标 | `游戏图标，圆形徽章构图，<内容>，禅意水墨风格，米色宣纸底徽章，深色描边，居中，纯绿色纯色背景，色值00FF00…`（同上去背） |
| 背景 | `禅意水墨<山水/场景>画，<景物>，大面积留白，淡雅米色宣纸底色，画满整个画面，无边框，无装裱，无卷轴，无文字，无印章，无水印，游戏场景背景`（「横幅」会出成卷轴立轴，禁用） |

qwen 吃中文提示词；flux2 中文效果差时把骨架整体译成英文。骨架本身可按用户反馈调整，调整后要回填本表保持一致。

## GPT Image（OpenAI 网关通道）

用户明确点名 image2 / image2.5 时用 `tools/comfy/gptimg.py`（网关是 LiteLLM，地址与 key 在 `tools/comfy/config.json` 的 `litellm` 段，环境变量 `LITELLM_URL` / `LITELLM_API_KEY` 可覆盖）：

```bash
python tools/comfy/gptimg.py run Azure-gpt-image-2 --prompt "游戏UI图标：下一关按钮，圆形徽章构图" \
  --count 3 --background transparent --out tools/comfy/out/next
```

- 模型名原样提交、无别名：用户嘴里的 image2 = 网关上的 `Azure-gpt-image-2`（image2.5 目前网关未上线）；不确定时先 `ping` 查实际模型名
- `--size`：1024x1024 / 1536x1024 / 1024x1536；`--quality`：low/medium/high；`--count` 映射 API 的 `n`，单请求出多张
- 与 ComfyUI 的差异：**无 seed（不可复现）、无负向提示词**；迭代靠改 prompt 重跑，同系列别指望锁构图
- `--background transparent` 直接出透明底（图标免去背）；生成偏慢，Bash timeout 给足（≥ 300s）
- 中英文提示词都吃，句式骨架沿用上表

## 落盘约定

| 资源类型 | 目录 | 命名 |
|---|---|---|
| 瓦片贴图 | `assets/art/tiles/` | `<物件名>.png`（如 `water.png`、`rock.png`） |
| 小和尚 sprite | `assets/art/player/` | 跟现有文件风格（如 `monk.png`） |
| UI 图标 | `assets/art/ui/` | `icon_<语义>.png` |
| 背景 | `assets/art/background/` | `bg_<场景名>.png` |
| 其他美术 | `assets/art/<子类>/` | 语义化命名，新增子类同步回填本表 |

风格一致性优先：同系列资源必须同 checkpoint、同风格前缀（固化在模板的 prompt 占位符外围），宁可牺牲单张惊喜感。
