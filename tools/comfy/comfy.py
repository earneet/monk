#!/usr/bin/env python3
"""ComfyUI 命令行客户端：提交工作流模板 → 轮询 → 下载产物到本地。

模板为 ComfyUI 网页导出的 API 格式 JSON（设置 → Enable Dev Mode Options → Save (API Format)），
要参数化的字段写成 {{名字}} 占位符，运行时用 --set 名字=值 替换；数字字段会保持数字类型。
产物类型无关：图片/音频/视频，凡工作流里有保存节点落盘的都会收集下载（专用后处理如
BGM 转 ogg 见 sa3.py）。

用法:
  python comfy.py ping                              # 连通性检查
  python comfy.py models [checkpoint|lora|...]      # 列服务器上的模型资源
  python comfy.py workflows                         # 列本地模板及占位符
  python comfy.py run <模板> [--set k=v]... [--out 路径] [--count N]

地址解析顺序：--url 参数 > 环境变量 COMFY_URL > tools/comfy/config.json 的 comfyui.url > http://127.0.0.1:8188
"""

import argparse
import http.client
import json
import os
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
WORKFLOWS_DIR = SCRIPT_DIR / "workflows"
OUT_DIR = SCRIPT_DIR / "out"
DEFAULT_URL = "http://127.0.0.1:8188"
PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")

# models 命令：资源种类 → (/object_info 节点, 字段)
NODE_FOR = {
    "checkpoint": ("CheckpointLoaderSimple", "ckpt_name"),
    "unet": ("UNETLoader", "unet_name"),
    "lora": ("LoRALoader", "lora_name"),
    "vae": ("VAELoader", "vae_name"),
    "sampler": ("KSampler", "sampler_name"),
    "scheduler": ("KSampler", "scheduler"),
    "upscale": ("UpscaleModelLoader", "model_name"),
}


def resolve_url(flag_url: str | None) -> str:
    if flag_url:
        return flag_url.rstrip("/")
    if env := os.environ.get("COMFY_URL"):
        return env.rstrip("/")
    cfg = SCRIPT_DIR / "config.json"
    if cfg.is_file():
        try:
            return json.loads(cfg.read_text("utf-8"))["comfyui"]["url"].rstrip("/")
        except (KeyError, ValueError):
            pass
    return DEFAULT_URL


def http_get(url: str, timeout: float = 30, retries: int = 3) -> bytes:
    """GET 带重试：内网服务器偶发断连（IncompleteRead/连接重置），幂等接口重试安全。

    HTTPError 不重试（4xx/5xx 是服务器明确答复，重试无意义），上抛给调用方处理。
    """
    last: Exception = RuntimeError("unreachable")
    for _ in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as resp:
                return resp.read()
        except urllib.error.HTTPError:
            raise
        except (http.client.IncompleteRead, ConnectionError, TimeoutError,
                urllib.error.URLError) as e:
            last = e
            time.sleep(1)
    raise last


def request_json(url: str, payload: dict | None = None) -> dict:
    if payload is None:  # GET 走重试；POST（/prompt 提交）非幂等，断连不重试
        return json.loads(http_get(url))
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def replace_value(text: str, params: dict):
    m = PLACEHOLDER.fullmatch(text)
    if m and m.group(1) in params:
        raw = params[m.group(1)]
        for cast in (int, float):  # 数字字段保持数字类型
            try:
                return cast(raw)
            except (TypeError, ValueError):
                pass
        return raw
    # 嵌在字符串里的占位符做文本插值，未提供的不动
    return PLACEHOLDER.sub(lambda m: str(params.get(m.group(1), m.group(0))), text)


def substitute(node: Any, params: dict) -> Any:
    if isinstance(node, dict):
        return {k: substitute(v, params) for k, v in node.items()}
    if isinstance(node, list):
        return [substitute(v, params) for v in node]
    if isinstance(node, str):
        return replace_value(node, params)
    return node


def find_template(name: str) -> Path:
    for cand in (Path(name), WORKFLOWS_DIR / name, WORKFLOWS_DIR / f"{name}.json"):
        if cand.is_file():
            return cand
    sys.exit(f"找不到模板 {name}（搜索：当前目录、{WORKFLOWS_DIR}）")


def submit(url: str, workflow: dict) -> str:
    try:
        resp = request_json(f"{url}/prompt", {"prompt": workflow, "client_id": uuid.uuid4().hex})
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        try:  # 校验失败时服务器返回节点级错误详情
            sys.exit(f"工作流校验失败：\n{json.dumps(json.loads(detail), ensure_ascii=False, indent=1)[:2000]}")
        except ValueError:
            sys.exit(f"提交失败 HTTP {e.code}：{detail[:500]}")
    return resp["prompt_id"]


def wait_history(url: str, prompt_id: str, timeout: float) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        hist = request_json(f"{url}/history/{prompt_id}")
        if prompt_id in hist:
            return hist[prompt_id]
        time.sleep(1)
    sys.exit(f"等待超时（{timeout:.0f}s）：prompt_id={prompt_id}")


def collect_outputs(entry: dict) -> list[dict]:
    """收集 history 里的全部落盘产物（图片/音频/视频…）。

    outputs 结构为 {nodeId: {类型键: [{filename, subfolder, type}, ...]}}，类型键随保存
    节点扩展（images/gifs/audio/videos…）——不按键名枚举，按「list 元素是含 filename 的
    dict」识别，未来新型产物节点自动支持。
    """
    files = []
    for out in entry.get("outputs", {}).values():
        files += [f for items in out.values()
                  if isinstance(items, list)
                  for f in items
                  if isinstance(f, dict) and "filename" in f]
    return files


def save_outputs(url: str, outputs: list[dict], out_arg: str | None, suffix: str) -> list[Path]:
    def with_suffix(path: Path, s: str) -> Path:
        return path if not s else path.with_name(f"{path.stem}{s}{path.suffix}")

    if out_arg and Path(out_arg).suffix and not Path(out_arg).is_dir():
        # 指定了文件路径：单个直接用，多个追加 _1.._N；扩展名由调用方保证与产物匹配
        base = with_suffix(Path(out_arg), suffix)
        targets = [base] if len(outputs) == 1 else [
            base.with_name(f"{base.stem}_{j}{base.suffix}") for j in range(1, len(outputs) + 1)]
    else:
        out_dir = Path(out_arg) if out_arg else OUT_DIR
        targets = [with_suffix(out_dir / item["filename"], suffix) for item in outputs]

    for item, target in zip(outputs, targets):
        target.parent.mkdir(parents=True, exist_ok=True)
        qs = urllib.parse.urlencode({k: item.get(k, "") for k in ("filename", "subfolder", "type")})
        target.write_bytes(http_get(f"{url}/view?{qs}", timeout=300))
    return targets


def cmd_ping(args):
    url = resolve_url(args.url)
    info = request_json(f"{url}/system_stats")
    ver = info.get("system", {}).get("comfyui_version", "?")
    dev = info["devices"][0] if info.get("devices") else {}
    print(f"ComfyUI {ver} @ {url} — {dev.get('type', '?')}: {dev.get('name', '?')}")


def cmd_models(args):
    url = resolve_url(args.url)
    for kind in ([args.kind] if args.kind else ["checkpoint", "unet", "lora"]):
        node, field = NODE_FOR[kind]
        try:
            info = request_json(f"{url}/object_info/{node}")
            options = info[node]["input"]["required"][field][0]
        except (urllib.error.HTTPError, KeyError):
            print(f"{kind}: 服务器没有 {node} 节点，跳过")
            continue
        print(f"{kind} ({len(options)}):")
        for name in options:
            print(f"  {name}")


def cmd_workflows(_):
    files = sorted(WORKFLOWS_DIR.glob("*.json")) if WORKFLOWS_DIR.is_dir() else []
    if not files:
        sys.exit(f"没有模板：把 API 格式 JSON 放进 {WORKFLOWS_DIR}（见该目录 README.md）")
    for f in files:
        params = ", ".join(sorted(set(PLACEHOLDER.findall(f.read_text("utf-8"))))) or "-"
        print(f"{f.stem}  [{params}]")


def find_unfilled(node: Any) -> list[str]:
    """收集替换后仍独占整个值的占位符——原样提交必然导致服务器校验失败。"""
    if isinstance(node, dict):
        return [x for v in node.values() for x in find_unfilled(v)]
    if isinstance(node, list):
        return [x for v in node for x in find_unfilled(v)]
    if isinstance(node, str) and (m := PLACEHOLDER.fullmatch(node)):
        return [m.group(1)]
    return []


def cmd_run(args):
    url = resolve_url(args.url)
    template = find_template(args.template)
    raw = template.read_text("utf-8")
    workflow = json.loads(raw)
    params = dict(s.split("=", 1) for s in args.set or [])
    params.setdefault("negative", "")  # 负向提示词缺省为空串，避免占位符原样进 prompt
    placeholders = set(PLACEHOLDER.findall(raw))

    # 模板参数化了 batch_size 时，--count 映射为单请求多个（批内噪声天然不同，比多次请求快）
    batched = "batch" in placeholders
    for i in range(1 if batched else args.count):
        suffix = f"_{i + 1}" if not batched and args.count > 1 else ""
        run_params = dict(params)
        if batched:
            run_params["batch"] = args.count
        if "seed" in placeholders and run_params.get("seed", "random") in ("random", "-1", ""):
            run_params["seed"] = random.randint(0, 2**32 - 1)
        started = time.monotonic()
        wf: dict = substitute(workflow, run_params)
        if unfilled := find_unfilled(wf):
            sys.exit(f"模板参数未提供：{', '.join(sorted(set(unfilled)))}（用 --set 名字=值 补齐）")
        prompt_id = submit(url, wf)
        entry = wait_history(url, prompt_id, args.timeout)
        status = entry.get("status", {})
        if status.get("status_str") != "success":
            sys.exit(f"执行失败：{json.dumps(status, ensure_ascii=False)[:2000]}")
        outputs = collect_outputs(entry)
        if not outputs:
            sys.exit("执行完成但没有产出（检查模板里的 SaveImage / 音频保存节点）")
        for p in save_outputs(url, outputs, args.out, suffix):
            print(p.resolve())
        print(f"# seed={run_params.get('seed')} 耗时 {time.monotonic() - started:.1f}s prompt_id={prompt_id}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_url(p):
        p.add_argument("--url", help=f"ComfyUI 地址（默认 {DEFAULT_URL}，或环境变量 COMFY_URL、config.json 的 comfyui.url）")

    p = sub.add_parser("ping", help="连通性检查")
    add_url(p)
    p.set_defaults(func=cmd_ping)

    p = sub.add_parser("models", help="列出服务器上的模型资源")
    add_url(p)
    p.add_argument("kind", nargs="?", choices=sorted(NODE_FOR), help="默认列 checkpoint + lora")
    p.set_defaults(func=cmd_models)

    p = sub.add_parser("workflows", help="列出本地模板及占位符")
    p.set_defaults(func=cmd_workflows)

    p = sub.add_parser("run", help="执行模板并下载产物")
    add_url(p)
    p.add_argument("template", help="模板名（可省略 workflows/ 前缀和 .json 后缀）")
    p.add_argument("--set", action="append", metavar="k=v", help="替换模板占位符，可多次")
    p.add_argument("--out", help="落盘路径：目录则用服务器原文件名，文件则作为基底名（扩展名须与产物类型匹配）；缺省存 tools/comfy/out/")
    p.add_argument("--count", type=int, default=1,
                   help="候选个数：模板含 {{batch}} 时单请求批量出（推荐，快），否则多次请求；默认 1")
    p.add_argument("--timeout", type=int, default=600, help="单次执行超时秒数，默认 600")
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
