#!/usr/bin/env node
// godot-mcp stdio 驱动：直接与 .mcp.json 配置的 godot-mcp 服务器对话。
// 用法:
//   node tools/dev/godot_mcp.mjs call <tool> '<json-args>' [waitMs]
//   node tools/dev/godot_mcp.mjs probe <scene-res-path> [waitMs]
//     = run_project(scene) → 等 waitMs → get_debug_output → stop_project
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";

const SERVER = "F:\\workspace_2\\godot-mcp\\build\\index.js";
const PROJECT = "F:\\workspace_2\\monk";
const [, , mode, a1, a2] = process.argv;

// 透传 .mcp.json 里声明的 env（如 GODOT_PATH），与编辑器/客户端行为一致
const mcpEnv = JSON.parse(readFileSync(`${PROJECT}\\.mcp.json`, "utf8")).mcpServers["godot-mcp"].env ?? {};

const proc = spawn(process.execPath, [SERVER], {
  stdio: ["pipe", "pipe", "pipe"],
  env: { ...process.env, ...mcpEnv },
});
let buf = "";
const pending = new Map();
let nextId = 1;

proc.stdout.on("data", (d) => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id && pending.has(msg.id)) {
        pending.get(msg.id)(msg);
        pending.delete(msg.id);
      }
    } catch { /* 非JSON行忽略 */ }
  }
});
proc.stderr.on("data", (d) => process.stderr.write(d));
proc.on("exit", (code) => console.error(`[mcp-server exit ${code}]`));

function request(method, params) {
  const id = nextId++;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    proc.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}

function printResult(label, resp) {
  if (!resp) { console.log(`${label}: <no response>`); return; }
  if (resp.error) { console.log(`${label} ERROR: ${JSON.stringify(resp.error)}`); return; }
  for (const c of resp.result?.content ?? []) {
    if (c.type === "text") console.log(`${label}: ${c.text}`);
  }
}

async function call(tool, args, label = tool) {
  const resp = await request("tools/call", { name: tool, arguments: args });
  printResult(label, resp);
  return resp;
}

await request("initialize", {
  protocolVersion: "2024-11-05",
  capabilities: {},
  clientInfo: { name: "zcode-driver", version: "0.1" },
});
proc.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

if (mode === "call") {
  await call(a1, JSON.parse(a2 || "{}"));
} else if (mode === "probe") {
  await call("run_project", { projectPath: PROJECT, scene: a1 }, "run_project");
  const total = parseInt(a2 || "6000", 10);
  let lastLen = -1;
  for (let elapsed = 0; elapsed < total; elapsed += 1000) {
    await new Promise((r) => setTimeout(r, 1000));
    const resp = await request("tools/call", { name: "get_debug_output", arguments: {} });
    const text = resp.result?.content?.[0]?.text ?? "";
    const output = (() => {
      try {
        const o = JSON.parse(text).output ?? "";
        return Array.isArray(o) ? o.join("\n") + "\n" : String(o);
      } catch { return ""; }
    })();
    if (output.length > lastLen) {
      process.stdout.write(output.slice(lastLen < 0 ? 0 : lastLen));
      lastLen = output.length;
    }
  }
  await call("stop_project", {}, "stop_project");
} else {
  console.error("用法: node godot_mcp.mjs call <tool> <json> [waitMs] | probe <scene> [waitMs]");
  process.exit(2);
}
proc.kill();
await new Promise((r) => setTimeout(r, 200));
process.exit(0);
