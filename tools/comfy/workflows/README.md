# 工作流模板

## 导出方法

1. 浏览器打开 ComfyUI → 右下角设置齿轮 → 勾选 **Enable Dev Mode Options**
2. 搭好工作流 → 菜单点 **Save (API Format)** 导出 JSON，放进本目录
3. 把每次要改的字段改成占位符 `{{名字}}`

## 占位符约定

| 占位符 | 位置 | 说明 |
|---|---|---|
| `{{prompt}}` | 正向 CLIP Text Encode 的 text | 主提示词 |
| `{{negative}}` | 负向 CLIP Text Encode 的 text | 缺省为空串 |
| `{{seed}}` | KSampler 的 seed | 运行时未指定则自动随机 |
| `{{width}}` `{{height}}` | Empty Latent Image | 尺寸 |
| `{{checkpoint}}` | CheckpointLoaderSimple 的 ckpt_name | 换模型用 |

占位符一律写成带引号的字符串 `"{{名字}}"`，保证模板是合法 JSON；脚本替换时独占整个值的占位符会自动恢复数字类型（如 `"{{width}}"` → `1024`），嵌在字符串里的做文本插值。
参考 `qwen.json`。

## 现有模板

- `qwen.json` —— qwen-image-2512-Q4_K_M + Qwen2.5-VL 文本编码器，约 9s/张
- `flux2.json` —— flux2-dev-turbo-Q4_K_M + mistral 文本编码器，约 33s/张
- `qwen_pixel.json` —— qwen + 像素风 LoRA（strength 0.85/0.75），20 步/cfg=2，约 40s/张，负向生效
- `sa3_audio.json` —— Stable Audio 3 音频（音乐/音效）：中文短描述 → qwen3.5 LLM 重写成专业英文提示词 → 生成 WAV。占位符 `{{prompt}}`（中文描述）`{{mode}}`（Music/Instrument/SFX/One-shot）`{{duration}}`（秒）`{{seed}}`。日常用 `sa3.py sfx|music` 封装好的子命令，别手搓 `--set`

`qwen`/`flux2` 为 turbo 档（负向提示词不生效）。资源类型靠 prompt + 尺寸区分，不另建模板。新模型/LoRA 按上面的导出方法加入即可。

产物收集类型无关：`comfy.py run` 会下载工作流里任何保存节点落盘的产物（图片/音频/视频…），视频等新型资源只需加模板即可用；需要后处理的（如 BGM 转 ogg）另写 sa3.py 这样的薄封装。
