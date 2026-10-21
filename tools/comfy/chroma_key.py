#!/usr/bin/env python3
"""绿幕出图 → 透明底 sprite 的本地去背工具。

服务器端 RemBG 模型未安装（models/background_removal 为空，不支持按需下载），
玩家 sprite 等「非满铺贴图」改走：ComfyUI 出纯绿底图 → 本工具键绿成透明底。

流程：绿色候选掩码 → 从图像边缘 flood-fill（只清与边缘连通的绿，保护角色
身上的绿色）→ 边界带去绿溢色（g 压回 max(r,b)）→ alpha 高斯羽化 → 可选
按内容裁切/缩放，输出 RGBA PNG。

用法:
  python chroma_key.py in.png out.png [--tol 60] [--feather 1.2]
                      [--trim 16] [--out-size 0]

绿判定：g - max(r, b) > tol（饱和绿幕 #00FF00 稳定命中；水墨风角色低饱和，
几乎不会误伤）。flood-fill 期间允许向「弱绿」扩散 tol/3，吃掉边缘绿晕。
"""

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def green_mask(rgb: np.ndarray, tol: int) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    m = g - np.maximum(r, b)
    return m > tol, m


def flood_from_border(cand: np.ndarray, weak: np.ndarray) -> np.ndarray:
    """从四边开始，强绿处入队，向弱绿扩散；返回与边缘连通的掩码。"""
    h, w = cand.shape
    seed = np.zeros((h, w), dtype=bool)
    seed[0, :] = cand[0, :] | weak[0, :]
    seed[-1, :] = cand[-1, :] | weak[-1, :]
    seed[:, 0] |= cand[:, 0] | weak[:, 0]
    seed[:, -1] |= cand[:, -1] | weak[:, -1]
    visited = np.zeros((h, w), dtype=bool)
    q = deque(zip(*np.nonzero(seed)))
    while q:
        y, x = q.popleft()
        if visited[y, x]:
            continue
        visited[y, x] = True
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] \
                    and (cand[ny, nx] or weak[ny, nx]):
                q.append((ny, nx))
    return visited


def despill(rgb: np.ndarray, band: np.ndarray) -> np.ndarray:
    out = rgb.copy()
    r = out[:, :, 0].astype(np.int16)
    g = out[:, :, 1].astype(np.int16)
    b = out[:, :, 2].astype(np.int16)
    cap = np.maximum(r, b)
    over = (g > cap) & band
    out[:, :, 1] = np.where(over, cap, g).astype(np.uint8)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--tol", type=int, default=60, help="绿判定阈值：g - max(r,b) > tol 视为绿幕")
    ap.add_argument("--feather", type=float, default=1.2, help="alpha 边缘高斯羽化半径(px)")
    ap.add_argument("--trim", type=int, default=0, help="按 alpha 内容裁切并留该像素边距（0=不裁）")
    ap.add_argument("--out-size", type=int, default=0, help="输出缩放到该边长（保持宽高比；0=原尺寸）")
    args = ap.parse_args()

    im = Image.open(args.src).convert("RGB")
    rgb = np.asarray(im)
    cand, margin = green_mask(rgb, args.tol)
    weak, _ = green_mask(rgb, max(args.tol // 3, 8))
    keyed = flood_from_border(cand, weak)
    alpha = np.where(keyed, 0, 255).astype(np.uint8)

    a_img = Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(args.feather))
    alpha = np.asarray(a_img)
    band = np.asarray(Image.fromarray(np.where(keyed, 255, 0).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(max(args.feather * 2.0, 2.0)))) > 0
    rgb = despill(rgb, band)

    rgba = np.dstack([rgb, alpha])
    out = Image.fromarray(rgba, "RGBA")
    if args.trim > 0:
        bbox = a_img.getbbox()
        if bbox is not None:
            l, t, r_, b_ = bbox
            out = out.crop((max(0, l - args.trim), max(0, t - args.trim),
                            min(out.width, r_ + args.trim), min(out.height, b_ + args.trim)))
    if args.out_size > 0:
        scale = args.out_size / max(out.width, out.height)
        out = out.resize((round(out.width * scale), round(out.height * scale)), Image.LANCZOS)

    out.save(args.dst)
    kept = (alpha > 0).sum() * 100 // alpha.size
    print(f"{Path(args.src).name} {im.width}x{im.height} -> {Path(args.dst).name} "
          f"{out.width}x{out.height} opaque={kept}%")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
