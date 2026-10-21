# 美术资源清单

全部由 `tools/comfy` 工具链生成（ComfyUI qwen-image-2512 Q4，禅意水墨风格句式），
批内多候选人工筛选后落盘。复现：`python tools/comfy/comfy.py run qwen --set "prompt=<prompt>"
--set seed=<seed> --set width=.. --set height=.."`（batch 生成时批内序号不可精确复现，
重跑同 seed 出同风格新候选）。

| 文件 | 来源 | prompt 摘要 | seed |
|---|---|---|---|
| tiles/floor.png | b2 #2 | 青石板地面纹理特写，方正石板铺满画面 | 4255015826 |
| tiles/wall.png | b1 #1 | 园林假山太湖石，深灰嶙峋岩石 | 886028928 |
| tiles/water.png | b1 #2 | 溪流水面，淡青色水波涟漪 | 193801137 |
| tiles/lever.png | b1 #2 | 石板地面中央圆形青铜机关踏板 | 1953390008 |
| tiles/door.png | b1 #2 | 关闭的古寺红漆木门，铜钉门环 | 2398401684 |
| tiles/bridge.png | b2 #2 裁切 | 旧木桥桥面，横向木板（居中裁掉栏杆） | 1865748924 |
| tiles/dwater.png | b1 #2 | 清澈浅水洼，卵石隐约可见 | 3100219243 |
| tiles/portal.png | b1 #2 | 古代法阵传送阵，青紫发光符文圆环 | 4156047973 |
| tiles/swept.png | b3 #2 | 枯山水白砂同心波纹砂纹 | 3370144045 |
| player/monk.png | b1 #3 | Q版小和尚橙黄僧袍双手合十，绿幕出图后 `chroma_key.py` 去背 | 2067672085 |
| background/bg_temple.png | b3 #1 | 禅意水墨山水，远山云雾古寺 | 1333870229 |

约定：瓦片 256×256 PNG（源 1024 降采样）；玩家 sprite 透明底；背景保留原尺寸。
风格句式骨架与候选审查流程见 `.agents/skills/gen-asset/SKILL.md`。
