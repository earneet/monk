# 实施设计:monk 关卡设计工具增量——undo(路径撤销)

> **任务来源**: 关卡工具机制标注增量(main=275e601,89 测试绿)完成后,用户选「关卡工具增量」并「全做」4 个子增量(undo/obstacle 微调/拖拽/自动生成),按 undo→obstacle→拖拽→自动生成 顺序推进。本 spec 是 undo 子批次(第一个)的实施级设计。
> **任务内容**: 关卡工具加 undo——撤销 path 末格(+ 连带该格机制标注),解决「画错只能清空重来」的编辑痛点。
> **参考文档**:
> - `docs/project/2026-07-09-level-design-tool-design.md` — 设计级 spec(§7 路径输入提及 undo/redo)
> - `docs/superpowers/specs/2026-07-12-level-design-tool-mvp-design.md` — MVP spec(前置)
> - `docs/superpowers/specs/2026-07-12-level-tool-mechanics-design.md` — 机制标注 spec(前置)
> - `scripts/tool/work_level_resource.gd` + `addons/level_designer/{main_view,level_canvas}.gd` — 现状接入点
> **生成日期**: 2026-07-12

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-12 |
| 状态 | 实施级 spec,待用户审 → writing-plans |
| 产物路径 | `docs/superpowers/specs/2026-07-12-level-tool-undo-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming(范围决策)→ 本文档 → writing-plans |
| 上游 | 设计级 spec §7、MVP/机制标注 spec、现状代码 |
| 下游 | writing-plans 逐步实施计划 |

## 1. 范围

**纳入**:
- `WorkLevelResource.undo_last_step() -> bool`:pop path 末格 + 删该格机制标注,返回是否撤销
- MainView 工具栏 undo 按钮
- GUT 测试 `undo_last_step`

**不纳入**:
- 完整 undo/redo 栈(多步撤销 + 重做,复杂、价值低,留后续)
- 机制标注加/删的独立 undo

## 2. 关键决策与理由(避免长期遗忘)

| # | 决策 | 理由 | 弃选替代及其原因 |
|---|---|---|---|
| D1 | undo = pop path 末格 + 连带删该格机制 | 画错回退是核心痛点;格不在 path 则其机制标注无意义,连带删保持 work 自洽 | 仅 pop path 不删机制:留孤儿机制(导出/校验错);完整栈:复杂过度 |
| D2 | 逻辑抽 `WorkLevelResource.undo_last_step()`(可测) | 逻辑/表现分离原则;@tool 表现层难测,抽模型方法 GUT 覆盖 | 内联 canvas:不可测、违反分离 |
| D3 | 不做 redo / 多步栈 | YAGNI;单步 undo 覆盖核心痛点,redo 价值低 | 完整 undo/redo 栈:复杂、维护重,当前不需要 |

## 3. 实现

`WorkLevelResource.undo_last_step()`:

```gdscript
func undo_last_step() -> bool:
    if path.is_empty():
        return false
    var last: Vector2i = path[path.size() - 1]
    path.pop_back()
    var i := 0
    while i < mechanics.size():
        if mechanics[i].coord == last:
            mechanics.remove_at(i)
        else:
            i += 1
    return true
```

MainView 工具栏加「撤销」按钮 → `canvas.work.undo_last_step()` → `canvas.queue_redraw()`。

## 4. 任务切片(TDD,喂给 writing-plans)

| # | 模块 | 红测 → 绿 | 测试 |
|---|---|---|---|
| 1 | `work_level_resource.gd` 加 `undo_last_step` | pop 末格 / 删该格机制 / 空 path 返回 false | GUT |
| 2 | MainView undo 按钮 | 手动:画错→撤销回退 | 手动 |

## 5. 验收

- [ ] `undo_last_step` pop path 末格 + 删该格机制,GUT 覆盖
- [ ] undo 按钮手动可用(画错回退,机制连带删)

## 执行中变更(D3 推翻,2026-07-12,用户验证反馈)

D3 原判断「不做栈(YAGNI)」被推翻:
- **变更**:undo 改为**反向操作栈**——编辑动作(path 追加/机制加/删)执行前 `push_undo(反向 lambda)`,`undo` LIFO 执行,撤销**最新动作**(非删 path 末格)。`WorkLevelResource.push_undo/undo`(去 `undo_last_step`);canvas `_try_append`/`_annotate` 编辑点 push_undo;`clear`/`size`/`goal` 不记 undo。
- **理由**:用户反馈原 undo(删末格)在标机制后撤销会错删 path 末格而非撤销机制标注;「撤销最新动作」是编辑器标准行为,D3 的 YAGNI 判断在此失误。
- **实际代码**:`scripts/tool/work_level_resource.gd`(`push_undo`/`undo`/`_undo_stack`)+ `addons/level_designer/level_canvas.gd`(`_try_append`/`_annotate` push_undo)。§3 的 `undo_last_step` 实现已被取代,以实际代码为准。
