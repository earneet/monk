# MenuDesigner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** 新建 MenuDesigner EditorPlugin,可视化编辑 WorldMapLayout(拖拽位置 + 拉连线建分叉 + 保存 validate)。

**Architecture:** `addons/menu_designer/`(plugin.gd EditorPlugin + main_view.gd @tool + canvas.gd @tool),平行 LevelDesigner。仿 level_designer/plugin.gd 模式。

**上游 spec:** `docs/superpowers/specs/2026-07-14-menu-designer-design.md`

**环境:** 同前(`$GODOT`; @tool 脚本改后编辑器重新加载;测试用现有 validate)。

---

## 文件结构

| 文件 | 责任 | 新 |
|---|---|---|
| `addons/menu_designer/plugin.cfg` | 插件元信息 | 新 |
| `addons/menu_designer/plugin.gd` | EditorPlugin(main screen "MenuDesigner") | 新 |
| `addons/menu_designer/main_view.gd` | toolbar(加载/保存/模式切换/添加) + 持 canvas | 新 |
| `addons/menu_designer/canvas.gd` | MenuCanvas:节点+连线 _draw + 左键拖移动 + 右键拉连线 | 新 |

## 任务

### Task md-1: plugin.cfg + plugin.gd + 注册
- 创建 plugin.cfg(Metadata "MenuDesigner") + plugin.gd(仿 level_designer)
- 编辑器启用插件(项目设置,不入 project.godot 的启用状态由用户/编辑器管)
- 验证:编辑器 main screen 出现 "MenuDesigner"

### Task md-2: canvas.gd 基础(节点显示 + 连线 _draw + 两级模式)
- MenuCanvas(@tool Control):持 layout/chapters/mode
- _draw:岛屿或关卡节点(按 mode) + next_ids 连线(空=默认下一)
- build(layout, chapters, mode, current_chapter_index) 构建

### Task md-3: canvas 左键拖拽移动
- _gui_input:左键按下节点 → 拖动改 entry.position → queue_redraw
- 命中检测(节点 Rect 含点)

### Task md-4: canvas 右键拉连线
- _gui_input:右键按下节点 → 拖动画临时连线 → 释放命中目标节点 → entry.next_ids += target_id
- 释放空白 → 取消
- 重复拉同一 edge → 不重复添加

### Task md-5: main_view.gd(toolbar + 加载/保存)
- toolbar:加载 .tres / 保存(validate 守门) / 模式 OptionButton(世界地图 + 各章节) / 添加岛屿/关卡
- 加载 world_map_layout.tres + resources/chapters/*.tres
- 持 canvas,build 委托

### Task md-6: 集成 + QA
- 编辑器启用插件,加载现有布局,拖拽/拉连线/保存/模式切换 QA
- 重载游戏确认新布局生效

## Self-Review
- D1/D2/D3 全覆盖;validate 守门(md-5);两级模式(md-2 mode);拉连线去重(md-4)。
