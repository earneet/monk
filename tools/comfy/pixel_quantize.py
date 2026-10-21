#!/usr/bin/env python3
"""AI 出图 → 项目像素风特效贴图的后处理器：降采样 + 限定调色板量化。

ComfyUI 出的 1024×1024 图无论 prompt 怎么锚定，原生都是渐变/低保真风；
命中项目"精细像素 + 2-5 色"规范必须靠本工具后处理（视觉审查已定案）。

流程：BOX 降采样（把 AI 的伪像素块平均成真像素）→ 感知加权最近色量化
→ 低于亮度阈值的像素保持纯黑（加法混合下即透明背景）。

2026-09-07 实机审计改造（分辨率方言根治，见 memory vfx-in-game-audit-2026-09）：
- 颗粒降档：1024 出图用 --factor 8（→128px 颗粒），配 --out-size 256 最近邻放大回
  原尺寸——贴图文件/场景 scale 零改动，纹理颗粒密度自动对齐场景 72px tile 档。
- 色带压紧：--colors 4 截断调色板（5-6 级同心环人眼读作平滑渐变；4 级以内才像像素色带）。

用法:
  python pixel_quantize.py in.png out.png [--factor 8] [--palette fire] [--bg 48]
                            [--dither] [--out-size 256]

调色板预设取自 combat/assets/vfx/ 下 hit_*/explosion_* 场景的实测 color_ramp，
首个白色为风格规范的热核色。新元素先从对应场景提取色带再往 PRESETS 加一行。
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

# 感知权重：人眼对绿最敏感、蓝最不敏感
WEIGHT_R, WEIGHT_G, WEIGHT_B = 2.0, 4.0, 3.0

PRESETS = {
    "fire":      ["FFFFFF", "FFFFCC", "FFB233", "E64C00", "661400"],
    "crimson":   ["FFFFFF", "FF6A4A", "CC2210", "7A150B", "400A04"],
    "ice":       ["FFFFFF", "E6F2FF", "80B2FF", "3366CC"],
    "lightning": ["FFFFFF", "99CCFF", "4C80FF", "1A3380"],
    "poison":    ["FFFFFF", "66FF4C", "40CC33", "1A661A"],
    "dark":      ["FFFFFF", "CC99FF", "8033B2", "330D4C"],
    "holy":      ["FFFFFF", "FFFFE6", "FFE680", "998033"],
    "execute":   ["FFFFFF", "FF3333", "CC1A1A", "4C0000"],
    "generic":   ["FFFFFF", "CCCCCC", "4C4C4C"],
    # 2026-09-07 精简板：删过渡色阶（3-4 级才读作像素色带而非渐变）。crimson4 无白——用户定案暗红调
    "fire4":     ["FFFFFF", "FFB233", "E64C00", "661400"],
    "crimson4":  ["FF6A4A", "CC2210", "7A150B", "400A04"],
    "ice4":      ["FFFFFF", "80B2FF", "3366CC"],
    "lightning4": ["FFFFFF", "4C80FF", "1A3380"],
    "poison4":   ["FFFFFF", "66FF4C", "1A661A"],
    "dark4":     ["FFFFFF", "CC99FF", "8033B2", "330D4C"],
    "holy4":     ["FFFFFF", "FFE680", "998033"],
}

# 4×4 Bayer 有序抖动矩阵（0-15），--dither 时把量化误差摊成像素级噪点，
# 避免 5 色量化后出现生硬色带
BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def hex2rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def distance(c1, c2) -> float:
    dr, dg, db = c1[0] - c2[0], c1[1] - c2[1], c1[2] - c2[2]
    return WEIGHT_R * dr * dr + WEIGHT_G * dg * dg + WEIGHT_B * db * db


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--factor", type=int, default=8, help="降采样倍数（1024 生成图用 8 → 128px 颗粒档；旧 256px 源重量化用 2）")
    ap.add_argument("--palette", choices=sorted(PRESETS), default="fire")
    ap.add_argument("--bg", type=int, default=48, help="max(r,g,b) 低于此值的像素保持纯黑（加法混合下透明）")
    ap.add_argument("--dither", action="store_true", help="开启 Bayer 有序抖动，缓解量化色带")
    ap.add_argument("--out-size", type=int, default=0, help="量化后最近邻放大到该边长（如 256）——替换现有贴图时保持文件尺寸，场景 scale 零改动")
    args = ap.parse_args()

    palette = [hex2rgb(h) for h in PRESETS[args.palette]]

    im = Image.open(args.src).convert("RGB")
    w, h = im.size
    small = im.resize((w // args.factor, h // args.factor), Image.BOX)
    sw, sh = small.size
    src = small.load()

    dst = Image.new("RGB", (sw, sh))
    out = dst.load()
    counts = [0] * len(palette)
    black = 0
    dither_bias = 32 if args.dither else 0  # 抖动扰动幅度（0-255 色阶内）

    for y in range(sh):
        for x in range(sw):
            r, g, b = src[x, y]
            if max(r, g, b) <= args.bg:
                out[x, y] = (0, 0, 0)
                black += 1
                continue
            if args.dither:
                k = (BAYER4[y & 3][x & 3] / 16.0 - 0.5) * dither_bias
                r, g, b = (max(0, min(255, round(v + k))) for v in (r, g, b))
            best, best_d = 0, float("inf")
            for i, c in enumerate(palette):
                d = distance((r, g, b), c)
                if d < best_d:
                    best, best_d = i, d
            out[x, y] = palette[best]
            counts[best] += 1

    if args.out_size > 0 and sw < args.out_size:
        dst = dst.resize((args.out_size, args.out_size * sh // sw), Image.NEAREST)
    dst.save(args.dst)

    total = sw * sh
    pal_hex = ["%02X%02X%02X" % c for c in palette]
    named = " ".join(f"{pal_hex[i]}={counts[i]*100//total}%" for i in range(len(palette)))
    print(f"{Path(args.src).name} {w}x{h} -> {Path(args.dst).name} {sw}x{sh} "
          f"[{args.palette}] black={black*100//total}% | {named}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
