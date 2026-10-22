# Demo 第 1–6 阶段规格索引

来源：[Notion《Demo入口》— Demo 开发顺序](https://app.notion.com/p/3e1f67bb9cfa810ca84ec25a5b6f485e)。

2026-10-22 根据用户确认的完成状态，核对现有源码与测试后补录。六个阶段分别保留独立的 proposal、design、spec 和 tasks，共 29 项任务，全部完成。OpenSpec 严格校验已通过；本轮未重新运行 Godot 测试或执行画面测试。

| 阶段 | Notion 开发内容 | OpenSpec 变更 | 规格 | 完成清单 |
| --- | --- | --- | --- | --- |
| 1 | 最小数据结构 | `add-core-match-data` | [数据契约](changes/add-core-match-data/specs/core-match-data/spec.md) | [5/5 已完成](changes/add-core-match-data/tasks.md) |
| 2 | 基础场景绘制 | `add-basic-field-environment` | [球场环境](changes/add-basic-field-environment/specs/field-environment/spec.md) | [4/4 已完成](changes/add-basic-field-environment/tasks.md) |
| 3 | 单个球员移动 | `add-single-player-movement` | [移动与转向](changes/add-single-player-movement/specs/player-movement/spec.md) | [4/4 已完成](changes/add-single-player-movement/tasks.md) |
| 4 | 持球与带球 | `add-ball-possession-and-dribbling` | [球权与带球](changes/add-ball-possession-and-dribbling/specs/ball-possession-and-dribbling/spec.md) | [4/4 已完成](changes/add-ball-possession-and-dribbling/tasks.md) |
| 5 | 射门与球运动 | `add-shooting-and-ball-motion` | [射门与球路](changes/add-shooting-and-ball-motion/specs/shooting-and-ball-motion/spec.md) | [5/5 已完成](changes/add-shooting-and-ball-motion/tasks.md) |
| 6 | 进球、出界与重置 | `add-goal-out-and-reset` | [边界与重置](changes/add-goal-out-and-reset/specs/goal-out-and-reset/spec.md) | [7/7 已完成](changes/add-goal-out-and-reset/tasks.md) |

## 开发与测试依赖

1. 最小数据结构提供统一表格、强类型定义、运行时与米制坐标。
2. 球场环境在数据基础上提供只读显示；基础逻辑单元测试不依赖环境渲染。
3. 移动在数据与固定步循环上独立运行。
4. 带球依赖移动与唯一球权模型。
5. 射门复用球权与动作时序，产生独立球路。
6. 边界与重置复用球场尺寸和球路，闭合“控球 → 带球 → 射门 → 进球或出界 → 重置 → 再次控球”。

## 本次补录范围

- 规格记录当前已经实现的行为，具体实现与测试证据列在各变更的 design.md 和 tasks.md。
- 早期设计中与当前行为不同的移动平滑方案、朝向、射门瞄准和出界结算，在各自设计文档中明确说明。
- 球员七项属性的全面接入、统一对抗、门将扑救、正式比赛、AI、词条及下注等后续特性的任务状态保持不变。
- 本次仅补文档；六份完成记录保留在 `openspec/changes/`，尚未执行归档或同步到 `openspec/specs/`。
