---
name: gen-audio
description: 调用 ComfyUI Stable Audio 3 生成游戏音频（音效、环境音、BGM 配乐），中文短描述自动重写为专业英文提示词，候选落盘、按 seed 复现、落盘到 assets/audio/。Use when 用户要生成音效/BGM/配乐/背景音乐/声音/音频，或提到 sa3/Stable Audio。
---

# gen-audio — 游戏音频生成

## 通道与命令

`python tools/comfy/sa3.py`（纯 stdlib，地址解析同 comfy.py：config.json 的 comfyui.url / COMFY_URL / --url）。服务器跑 Stable Audio 3 + qwen3.5：中文短描述 → LLM 重写成英文专业提示词 → 生成。命令从仓库根执行：

```bash
python tools/comfy/sa3.py ping                                            # 先查连通
python tools/comfy/sa3.py sfx --prompt "扫帚扫过石板，沙沙摩擦声" --count 3   # 音效：3 候选
python tools/comfy/sa3.py music --prompt "宁静祥和的寺院BGM" --count 3    # BGM（默认 150s）
```

| 参数 | 说明 |
|---|---|
| sfx / music | 预设子命令（mode=SFX+3s / Music+150s），`--mode`/`--duration` 可覆盖 |
| --mode | Music / Instrument / SFX / One-shot，语义见下 |
| --count | 候选数，逐次请求；seed 缺省每次随机 |
| --seed | 固定 seed 复现（count>1 按 seed、seed+1… 派生） |
| --raw | 跳过 LLM 重写，prompt 原文直发（建议写英文） |
| --out | 落盘路径；.ogg 结尾自动 ffmpeg 转码；缺省存 tools/comfy/out/ |

**mode 语义**：SFX=音效/环境音；One-shot=乐器单次采样（单音打击乐等）；Instrument=乐器循环段（loop 素材）；Music=完整曲目（BGM）。
**duration 参考**：打扫/脚步/机关触发 1–3s；UI 反馈 0.5–1s；环境音 6–15s；BGM 120–300s。

## 标准闭环

1. **确认语义**：短描述写清 声音来源+材质+空间+动态（如"扫帚扫过石板，木质柄+鬃毛刷，室内近场，轻快节奏"），别只堆名词
2. **出候选**：`--count 3` 先落 `tools/comfy/out/`，不直接进 assets
3. **人耳验收**：agent 听不了音频——把候选文件路径列给用户试听，不要假装能审查音频内容；由用户指定中意的一份
4. **复现落盘**：用该候选输出的 `# seed=` 值重跑同参数到目标路径（固定 seed + count 1 = 精确复现；LLM 重写节点 seed 固定，整体可复现）
5. **落盘**：按下述约定存入 `assets/audio/`
6. 单次生成慢（长音乐数分钟）：Bash timeout 给足（≥ `--timeout` 值）

## 落盘约定

| 资源类型 | 目录 | 命名 |
|---|---|---|
| 音效 | `assets/audio/sfx/` | `sfx_<语义>.wav`（如 `sfx_sweep.wav`） |
| BGM | `assets/audio/bgm/` | `bgm_<场景名>.ogg`（如 `bgm_temple.ogg`） |

- BGM 生成用 `--out assets/audio/bgm/<曲名>.ogg`（自动 ffmpeg 转码，26MB→1MB 级；无 ffmpeg 会回退存 wav，需装后重生成或自行转码）
- SA3 生成曲首尾非严格无缝，游戏内 loop 接缝由播放端淡入淡出掩盖
- `.import` 由 Godot 编辑器扫一次生成，随音频一起入库

## 游戏内接线（Godot）

项目音频系统落地后回填本节细节，当前方向：

- 音效：场景内 `AudioStreamPlayer`（或池化播放器）按事件触发，路径常量集中管理
- BGM：autoload 单例播放器（音量让位 SFX、同曲幂等不闪断、循环由播放器置 loop）
- 没确定接哪个事件就**先不落盘到 assets**——生成候选留在 `tools/comfy/out/`，避免死资源
