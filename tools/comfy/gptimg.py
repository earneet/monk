#!/usr/bin/env python3
"""GPT Image（OpenAI 兼容网关）生图客户端：POST /v1/images/generations → 解码落盘。

与 comfy.py 平行的另一条生图通道，仅当用户明确点名 image2 / image2.5 时使用，默认仍走 ComfyUI。

用法:
  python gptimg.py ping                                      # 连通性 + 鉴权检查
  python gptimg.py models                                    # 列网关上的模型名
  python gptimg.py run Azure-gpt-image-2 --prompt "..." --out out/fire
  python gptimg.py run Azure-gpt-image-2 --prompt "..." --count 3 --size 1536x1024

模型名原样提交（以 ping/models 查到的网关实际名为准，当前 GPT 生图模型是 Azure-gpt-image-2）。
地址/key 解析顺序: --url/--api-key 参数 > 环境变量 LITELLM_URL/LITELLM_API_KEY
                  > tools/comfy/config.json 的 litellm 段（复制 config.example.json）
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
OUT_DIR = SCRIPT_DIR / "out"
DEFAULT_URL = "http://127.0.0.1:4000"
SIZES = ("1024x1024", "1536x1024", "1024x1536")


def load_config() -> tuple[str | None, str | None]:
    cfg = SCRIPT_DIR / "config.json"
    if not cfg.is_file():
        return None, None
    try:
        sect = json.loads(cfg.read_text("utf-8")).get("litellm", {})
        return sect.get("url"), sect.get("api_key")
    except ValueError:
        return None, None


def resolve(args) -> tuple[str, str]:
    cfg_url, cfg_key = load_config()
    url = (args.url or os.environ.get("LITELLM_URL") or cfg_url or DEFAULT_URL).rstrip("/")
    key = args.api_key or os.environ.get("LITELLM_API_KEY") or cfg_key or ""
    if not key:
        sys.exit("缺少 API key：在 tools/comfy/config.json 填 litellm.api_key，或设环境变量 LITELLM_API_KEY")
    return url, key


def request_json(url: str, key: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, headers={
        "Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        try:  # 网关错误体是 JSON，把 message 提出来
            msg = json.loads(detail).get("error", {}).get("message", detail)
        except ValueError:
            msg = detail
        sys.exit(f"HTTP {e.code}：{msg[:1000]}")


def save_image(data: dict, out_arg: str | None, model: str, index: int) -> Path:
    if out_arg and Path(out_arg).suffix and not Path(out_arg).is_dir():
        base = Path(out_arg)
        target = base if index == 1 else base.with_name(f"{base.stem}_{index}{base.suffix}")
    else:
        out_dir = Path(out_arg) if out_arg else OUT_DIR
        target = out_dir / f"{model}_{index}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    if b64 := data.get("b64_json"):  # gpt-image 系列只回 b64
        target.write_bytes(base64.b64decode(b64))
    elif url := data.get("url"):  # dall-e 系回 url
        with urllib.request.urlopen(url, timeout=300) as resp:
            target.write_bytes(resp.read())
    else:
        sys.exit(f"第 {index} 张既无 b64_json 也无 url：{json.dumps(data, ensure_ascii=False)[:300]}")
    return target


def cmd_ping(args):
    url, key = resolve(args)
    data = request_json(f"{url}/v1/models", key)
    ids = [m.get("id", "?") for m in data.get("data", [])]
    print(f"{url} 鉴权通过，{len(ids)} 个模型")
    for i in ids:
        print(f"  {i}")


def cmd_models(args):
    url, key = resolve(args)
    data = request_json(f"{url}/v1/models", key)
    for m in data.get("data", []):
        print(m.get("id", "?"))


def cmd_run(args):
    url, key = resolve(args)
    model = args.model
    payload = {"model": model, "prompt": args.prompt, "n": args.count, "size": args.size}
    if args.quality != "auto":
        payload["quality"] = args.quality
    if args.background != "auto":
        payload["background"] = args.background
    if args.moderation != "auto":
        payload["moderation"] = args.moderation

    started = time.monotonic()
    resp = request_json(f"{url}/v1/images/generations", key, payload)
    images = resp.get("data", [])
    if not images:
        sys.exit(f"网关没返回图片：{json.dumps(resp, ensure_ascii=False)[:1000]}")
    for i, data in enumerate(images, 1):
        print(save_image(data, args.out, model, i).resolve())
    usage = resp.get("usage", {})
    print(f"# model={model} size={args.size} 耗时 {time.monotonic() - started:.1f}s"
          f" total_tokens={usage.get('total_tokens', '?')}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_conn(p):
        p.add_argument("--url", help=f"网关地址（默认 {DEFAULT_URL}，或环境变量 LITELLM_URL、config.json litellm.url）")
        p.add_argument("--api-key", help="API key（或环境变量 LITELLM_API_KEY、config.json litellm.api_key）")

    p = sub.add_parser("ping", help="连通性 + 鉴权检查，顺带列出模型")
    add_conn(p)
    p.set_defaults(func=cmd_ping)

    p = sub.add_parser("models", help="列出网关上的模型名")
    add_conn(p)
    p.set_defaults(func=cmd_models)

    p = sub.add_parser("run", help="生图并落盘")
    add_conn(p)
    p.add_argument("model", help="完整模型名，如 Azure-gpt-image-2（ping/models 可查）")
    p.add_argument("--prompt", required=True, help="提示词")
    p.add_argument("--size", default="1024x1024", choices=SIZES, help="默认 1024x1024")
    p.add_argument("--count", type=int, default=1, help="单请求出图张数（映射 API 的 n），默认 1")
    p.add_argument("--quality", default="auto", choices=("low", "medium", "high", "auto"), help="默认 auto")
    p.add_argument("--background", default="auto", choices=("transparent", "opaque", "auto"),
                   help="transparent 出透明底（图标去背用），默认 auto")
    p.add_argument("--moderation", default="auto", choices=("low", "auto"), help="内容审核松紧，默认 auto")
    p.add_argument("--out", help="落盘路径：目录则按 <模型>_<序号>.png 命名，文件则作为基底名；缺省存 tools/comfy/out/")
    p.set_defaults(func=cmd_run)

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
