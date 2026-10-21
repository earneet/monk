#!/usr/bin/env python3
"""Stable Audio 3 音频生成客户端：中文短描述 → LLM 重写 → SA3 生成 → WAV/OGG 落盘。

走 ComfyUI 的 sa3_audio 模板（LLM qwen3.5 把短描述重写成专业英文提示词再生成），
与 comfy.py 通用通道平行；地址解析复用 comfy.py 的逻辑。

用法:
  python sa3.py ping                                            # 连通性检查
  python sa3.py sfx  --prompt "挥剑打击，金属 clang" --out ../../combat/assets/sfx/swing.wav
  python sa3.py music --prompt "紧张刺激的战斗BGM" --duration 150 --out ../../combat/assets/bgm/battle.ogg
  python sa3.py sfx  --prompt "冰霜爆炸" --count 3               # 3 个候选（随机 seed）

sfx/music 只是预设：sfx = mode SFX + duration 3，music = mode Music + duration 150，
全部参数（--mode/--duration/--seed/...）均可命令行覆盖。--out 以 .ogg 结尾时自动调
ffmpeg 转码（BGM 体积从 26MB 级降到 1MB 级），无 ffmpeg 则回退保存 wav。
"""

import argparse
import json
import random
import shutil
import subprocess
import sys
import time
from pathlib import Path

import comfy

SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE = SCRIPT_DIR / "workflows" / "sa3_audio.json"

# 模板里的 LLM 重写开关节点（网页 UI 里是 PrimitiveBoolean 开关；命令行无 UI，--raw 按节点号直改 JSON 值）
NODE_REPROMPT = "83:78"
MODES = ("Music", "Instrument", "SFX", "One-shot")
PRESETS = {"sfx": {"mode": "SFX", "duration": 3}, "music": {"mode": "Music", "duration": 150}}


def to_ogg(wav: Path, ogg: Path):
    ogg.parent.mkdir(parents=True, exist_ok=True)  # ffmpeg/replace 都不会建目录，落盘前统一建好
    if not shutil.which("ffmpeg"):
        fallback = ogg.with_suffix(".wav")
        wav.replace(fallback)
        print(f"# 未找到 ffmpeg，已回退保存 {fallback}（装 ffmpeg 后可重生成或自行转码）")
        return
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                    "-c:a", "libvorbis", "-q:a", "5", str(ogg)], check=True)
    wav.unlink()


def cmd_ping(args):
    url = comfy.resolve_url(args.url)
    info = comfy.request_json(f"{url}/system_stats")
    ver = info.get("system", {}).get("comfyui_version", "?")
    dev = info["devices"][0] if info.get("devices") else {}
    print(f"ComfyUI {ver} @ {url} — {dev.get('type', '?')}: {dev.get('name', '?')}")


def cmd_gen(args):
    url = comfy.resolve_url(args.url)
    template = json.loads(TEMPLATE.read_text("utf-8"))
    if args.raw:
        template[NODE_REPROMPT]["inputs"]["value"] = False

    files = []
    for i in range(1, args.count + 1):
        params = {"prompt": args.prompt, "mode": args.mode,
                  "duration": args.duration, "seed": args.seed}
        if params["seed"] < 0:
            params["seed"] = random.randint(0, 2**32 - 1)
        elif i > 1:
            params["seed"] += i - 1  # 固定 seed 出多候选：按 seed、seed+1… 派生，否则 N 份完全相同
        wf = comfy.substitute(template, params)
        if unfilled := comfy.find_unfilled(wf):
            sys.exit(f"模板参数未提供：{', '.join(sorted(set(unfilled)))}")

        started = time.monotonic()
        prompt_id = comfy.submit(url, wf)
        entry = comfy.wait_history(url, prompt_id, args.timeout)
        status = entry.get("status", {})
        if status.get("status_str") != "success":
            sys.exit(f"执行失败：{json.dumps(status, ensure_ascii=False)[:2000]}")
        audio = comfy.collect_outputs(entry)
        if not audio:
            sys.exit("执行完成但没有产出音频（检查模板里的音频保存节点）")
        suffix = f"_{i}" if args.count > 1 else ""
        # .ogg 目标：先按服务器文件名落 wav 再转码，避免把 wav 字节写进 .ogg
        transcode = bool(args.out) and Path(args.out).suffix.lower() == ".ogg"
        out_arg = None if transcode else args.out
        for wav in comfy.save_outputs(url, audio, out_arg, suffix):
            if transcode:
                ogg = Path(args.out)
                ogg = ogg.with_name(f"{ogg.stem}{suffix}{ogg.suffix}") if args.count > 1 else ogg
                to_ogg(wav, ogg)
                files.append(ogg)
                print(ogg.resolve())
            else:
                files.append(wav)
                print(wav.resolve())
        print(f"# seed={params['seed']} mode={args.mode} duration={args.duration}s"
              f" 耗时 {time.monotonic() - started:.1f}s prompt_id={prompt_id}")
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_common(p):
        p.add_argument("--url", help="ComfyUI 地址（默认 http://127.0.0.1:8188，或环境变量 COMFY_URL、config.json 的 comfyui.url）")

    p = sub.add_parser("ping", help="连通性检查")
    add_common(p)
    p.set_defaults(func=cmd_ping)

    for name, preset in PRESETS.items():
        p = sub.add_parser(name, help=f"生成音频（预设 mode={preset['mode']} duration={preset['duration']}s，均可覆盖）")
        add_common(p)
        p.add_argument("--prompt", required=True, help="中文短描述，模板里的 LLM 会重写成专业英文提示词")
        p.add_argument("--mode", default=preset["mode"], choices=MODES, help=f"提示词重写类别，默认 {preset['mode']}")
        p.add_argument("--duration", type=float, default=preset["duration"],
                       help=f"音频时长秒数，默认 {preset['duration']}")
        p.add_argument("--count", type=int, default=1, help="候选个数（逐次请求；seed 缺省每次随机），默认 1")
        p.add_argument("--seed", type=int, default=-1, help="固定 seed 复现（count>1 时按 seed、seed+1… 派生），缺省随机")
        p.add_argument("--out", help="落盘路径：目录则用服务器原文件名，文件则作为基底名；.ogg 结尾自动 ffmpeg 转码；缺省存 tools/comfy/out/")
        p.add_argument("--raw", action="store_true", help="跳过 LLM 重写，prompt 原文直接进 SA3（建议写英文）")
        p.add_argument("--timeout", type=int, default=900, help="单次执行超时秒数（长音乐慢），默认 900")
        p.set_defaults(func=cmd_gen)

    args = ap.parse_args()
    # Windows 管道/控制台默认 GBK，强制 UTF-8 防乱码
    for stream in (sys.stdout, sys.stderr):
        if stream.encoding and stream.encoding.lower() not in ("utf-8", "utf8"):
            try:
                stream.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
            except Exception:
                pass
    args.func(args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
