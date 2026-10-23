"""从 raw/texture 的原画切分 monk 用美术资源 → assets/art/temple/。

原画: Gemini_Generated_Image_42wjkx42wjkx42wj.jpg (2752x1536, 石板间距 ~92px)。
游戏单格 72px, 故所有产出按 92→72 缩放; 地板图集为 4x4 块 72px 单板。
道具抠图: 边界洪泛填充, 颜色接近"地面色族"(含暗线/阴影亮度倍率) 判为背景。
用法: python tools/dev/slice_temple.py
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "raw/texture/Gemini_Generated_Image_42wjkx42wjkx42wj.jpg"
OUT = ROOT / "assets/art/temple"
TMP = ROOT / ".zcode/tmp"
CELL_SRC = 92.0  # 原画石板间距
CELL_PX = 72     # 游戏单格
SCALE = CELL_PX / CELL_SRC

# 地板: 逐格指定 16 块干净单板(x0,y0,x1,y1, 是否水平翻转), 线位全部来自检测
FLOOR_SLABS = [
    (1147, 727, 1237, 818, False), (1558, 727, 1651, 818, False), (1651, 635, 1742, 727, False), (1742, 635, 1835, 727, False),
    (1147, 818, 1237, 911, False), (1558, 818, 1651, 911, False), (1651, 727, 1742, 818, False), (1742, 727, 1835, 818, False),
    (1147, 911, 1237, 1003, False), (1558, 911, 1651, 1003, False), (1651, 818, 1742, 911, False), (1742, 818, 1835, 911, False),
    (1147, 1003, 1237, 1094, False), (1558, 727, 1651, 818, True), (1651, 911, 1742, 1003, False), (1742, 911, 1835, 1003, False),
]

# 道具: (名字, 框, 是否抠底)
PROPS = [
    ("pond", (300, 680, 1060, 1190), False),
    ("rockery", (1840, 655, 2500, 1070), False),
    ("tree_cherry_a", (230, 220, 560, 480), True),
    ("tree_cherry_b", (1665, 350, 1940, 585), True),
    ("tree_cherry_c", (1600, 1030, 1880, 1245), True),
    ("tree_pine_a", (2300, 215, 2520, 470), True),
    ("tree_pine_b", (230, 980, 505, 1235), True),
    ("lantern_w", (1125, 545, 1240, 685), True),
    ("lantern_e", (1525, 545, 1645, 685), True),
    ("burner", (895, 435, 1035, 565), True),
    ("stairs", (1230, 540, 1510, 645), False),
    ("dock", (255, 785, 445, 955), False),
    ("gate", (1120, 1110, 1580, 1500), True),
    ("wall_south", (350, 1240, 1100, 1480), False),
    ("wall_west", (150, 320, 255, 1140), False),
    ("hall_main", (980, 0, 1720, 450), True),
    ("hall_side_l", (470, 0, 980, 330), True),
    ("hall_side_r", (1740, 0, 2260, 330), True),
    ("path", (1235, 460, 1465, 1200), False),
    ("stream_strip", (560, 682, 1016, 806), False),
]

# 矩形裁切内的入侵物修补: 道具名 → [(框内相对区域, 用于回填的净地板区)]
PATCHES = {
    "pond": [((0, 290, 250, 510), (1147, 911, 1237, 1003))],
}


def detect_lines(band: np.ndarray, thresh: float = 8.0) -> list[int]:
    base = np.median(band)
    hits = [
        i
        for i in range(2, len(band) - 2)
        if band[i] < base - thresh and band[i] <= band[i - 1] and band[i] <= band[i + 1]
    ]
    merged: list[int] = []
    for v in hits:
        if merged and v - merged[-1] <= 4:
            continue
        merged.append(v)
    return merged


def snap(lines: list[int], target: float) -> int:
    return min(lines, key=lambda v: abs(v - target)) if lines else int(target)


def slice_floor(img: Image.Image) -> Image.Image:
    atlas = Image.new("RGBA", (4 * CELL_PX, 4 * CELL_PX), (0, 0, 0, 0))
    for i, (x0, y0, x1, y1, flip) in enumerate(FLOOR_SLABS):
        slab = img.crop((x0, y0, x1, y1))
        if flip:
            slab = slab.transpose(Image.FLIP_LEFT_RIGHT)
        atlas.paste(slab.resize((CELL_PX, CELL_PX), Image.LANCZOS), ((i % 4) * CELL_PX, (i // 4) * CELL_PX))
    return atlas


def floor_palette(img: Image.Image) -> np.ndarray:
    reg = np.asarray(img.crop((1480, 500, 1640, 830)), dtype=np.float32)
    return reg.reshape(-1, 3).mean(axis=0)


def cutout(prop: Image.Image, floor_rgb: np.ndarray, tol: float = 34.0) -> Image.Image:
    a = np.asarray(prop.convert("RGB"), dtype=np.float32)
    h, w = a.shape[:2]
    ks = [0.5, 0.62, 0.75, 0.9, 1.05, 1.2]
    pal = np.stack([floor_rgb * k for k in ks], axis=0)
    d = np.linalg.norm(a[:, :, None, :] - pal[None, None, :, :], axis=3).min(axis=2)
    bg = d < tol

    seen = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bg[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bg[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, :3] = np.asarray(prop.convert("RGB"))
    out[:, :, 3] = np.where(~seen, 255, 0)
    rgba = Image.fromarray(out, "RGBA")
    bbox = rgba.getbbox()
    return rgba.crop(bbox) if bbox else rgba


# 游戏内 tiles/ 贴图替换(原地覆盖, 依赖 grid_renderer 既有采样约定):
# floor 256x256=4x4 块 64px 单板; 其余用未补边的原比例裁切
GAME_TILES = {
    "floor.png": ("__atlas__", (288, 288)),  # 4x4 块 72px 单板, 1:1 进 72px 格
    "pond.png": ("pond", None),              # 整池原比例, 小体积 contain-fit 用
    "wall_h.png": ("wall_h", None),          # 南墙一柱距, 原生平铺
    "wall_v.png": ("wall_v", None),
    "pond_t.png": ("pond_t", None),
    "pond_b.png": ("pond_b", None),
    "pond_l.png": ("pond_l", None),
    "pond_r.png": ("pond_r", None),
    "water.png": ("water", None),
    "pond_corner_tl.png": ("corner_tl", None),
    "pond_corner_tr.png": ("corner_tr", None),
    "pond_corner_bl.png": ("corner_bl", None),
    "pond_corner_br.png": ("corner_br", None),
    "stream_narrow.png": ("stream_narrow", None),
    "stream_narrow_v.png": ("stream_narrow_v", None),
    "lever.png": ("lantern_w", None),
}



# 周期与水体图块: (名字, 源框) 92px 源格 → 72px
PERIOD_TILES = {
    "wall_h": (392, 1294, 530, 1490),   # 南墙一柱距(含柱), 原生平铺
    "wall_v": (140, 330, 245, 514),     # 西墙内面一段
    "pond_t": (620, 668, 712, 760),     # 池北缘平直段: 缘石+水
    "pond_b": (700, 1094, 792, 1186),   # 池南缘: 水+缘石
    "water": (900, 900, 992, 992),      # 池心净水
}
RIM_PX = 52  # 72px 图块中缘石厚度


def build_period_tiles(img: Image.Image) -> dict[str, Image.Image]:
    out: dict[str, Image.Image] = {}
    for name, box in PERIOD_TILES.items():
        im = img.crop(box).resize(
            (round((box[2] - box[0]) * SCALE), round((box[3] - box[1]) * SCALE)),
            Image.LANCZOS,
        )
        out[name] = im
    out["pond_l"] = out["pond_t"].transpose(Image.ROTATE_90)
    out["pond_r"] = out["pond_t"].transpose(Image.ROTATE_270)

    def corner(l: Image.Image, band: Image.Image, top: bool) -> Image.Image:
        c = out["water"].copy()
        c.paste(l, (0, 0))
        b = band.crop((0, 0, 72, RIM_PX)) if top else band.crop((0, 72 - RIM_PX, 72, 72))
        c.paste(b, (0, 0 if top else 72 - RIM_PX))
        return c

    out["corner_tl"] = corner(out["pond_l"], out["pond_t"], True)
    out["corner_tr"] = corner(out["pond_r"], out["pond_t"], True)
    out["corner_bl"] = corner(out["pond_l"], out["pond_b"], False)
    out["corner_br"] = corner(out["pond_r"], out["pond_b"], False)
    narrow = out["water"].copy()
    narrow.paste(out["pond_t"].crop((0, 0, 72, RIM_PX)), (0, 0))
    narrow.paste(out["pond_b"].crop((0, 72 - RIM_PX, 72, 72)), (0, 72 - RIM_PX))
    out["stream_narrow"] = narrow
    out["stream_narrow_v"] = narrow.transpose(Image.ROTATE_90)
    return out

def export_game_tiles(tiles: dict[str, Image.Image], atlas: Image.Image) -> None:
    game_dir = ROOT / "assets/art/tiles"
    for target, (src_name, mod) in GAME_TILES.items():
        if src_name == "__atlas__":
            im = atlas.resize(mod, Image.LANCZOS)
        else:
            im = tiles[src_name]
            if mod == "flip":
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(game_dir / target)
        print(f"game tile {target} ← {src_name} {im.size}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    TMP.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGB")

    atlas = slice_floor(img)
    atlas.save(OUT / "atlas_floor.png")
    print("atlas_floor.png", atlas.size)

    floor_rgb = floor_palette(img)
    tiles: dict[str, Image.Image] = {}
    for name, box, matte in PROPS:
        crop = img.crop(box)
        for prect, fslab in PATCHES.get(name, []):
            sx0, sy0, sx1, sy1 = fslab
            slab = img.crop((sx0, sy0, sx1, sy1))
            pw, ph = prect[2] - prect[0], prect[3] - prect[1]
            sw, sh = slab.size
            fill = Image.new("RGB", (pw, ph))
            for ty in range(0, ph, sh):
                for tx in range(0, pw, sw):
                    fill.paste(slab, (tx, ty))
            crop.paste(fill, (prect[0], prect[1]))
        if matte:
            crop = cutout(crop, floor_rgb)
        else:
            crop = crop.convert("RGBA")
        crop = crop.resize(
            (max(1, round(crop.width * SCALE)), max(1, round(crop.height * SCALE))),
            Image.LANCZOS,
        )
        crop.save(OUT / f"{name}.png")
        tiles[name] = crop
        print(f"{name}.png", crop.size)

    periods = build_period_tiles(img)
    for name, im in periods.items():
        im.save(OUT / f"{name}.png")
        tiles[name] = im
        print(f"{name}.png", im.size)
    scene = img.resize((30 * CELL_PX, 17 * CELL_PX), Image.LANCZOS)
    scene.save(OUT / "atlas_scene.png")
    print("atlas_scene.png", scene.size)

    export_game_tiles(tiles, atlas)

    wall_west = Image.open(OUT / "wall_west.png")
    wall_east = wall_west.transpose(Image.FLIP_LEFT_RIGHT)
    wall_east.save(OUT / "wall_east.png")
    tiles["wall_east"] = wall_east

    # 补边到 72 整数倍画布(底边居中锚定), 供 TileSet 多格 tile 使用
    for f in sorted(OUT.glob("*.png")):
        if f.name == "atlas_floor.png" or f.name == "temple_tileset.tres":
            continue
        im = Image.open(f)
        cw = -(-im.width // CELL_PX) * CELL_PX
        ch = -(-im.height // CELL_PX) * CELL_PX
        if (cw, ch) == im.size:
            continue
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.paste(im, ((cw - im.width) // 2, ch - im.height))
        canvas.save(f)
        print(f"padded {f.name} → {(cw, ch)}")

    sheet = Image.new("RGB", (4 * 296 + 8, 5 * 220 + 8), (40, 44, 48))
    for i, (name, t) in enumerate(tiles.items()):
        s = min(288 / t.width, 184 / t.height, 1.0)
        r = t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)
        x = 8 + (i % 4) * 296
        y = 8 + (i // 4) * 220
        sheet.paste(r, (x, y), r)
    sheet.save(TMP / "temple_contact.png")
    print("contact sheet →", TMP / "temple_contact.png")


if __name__ == "__main__":
    main()
