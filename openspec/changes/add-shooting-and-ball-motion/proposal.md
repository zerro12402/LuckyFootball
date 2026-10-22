# Proposal

## Why

Notion《Demo入口》第 5 项“射门与球运动”已完成，需要记录从持球动作到足球独立运动的契约，形成可验证的单人射门基线。

## What Changes

- 补录射门资格、自动朝对方球门、动作前摇触球和后摇恢复。
- 补录力度与射门属性的球速映射、独立运动、弧线高度与减速停止。
- 完成清单基于既有实现与测试，本次仅新增文档。

## Capabilities

### New Capabilities

- `shooting-and-ball-motion`: 基础射门释放和无主足球独立运动。

### Modified Capabilities

无。

## Impact

- 依赖 `core-match-data`、`player-movement`、`ball-possession-and-dribbling`。
- 已有实现：比赛模拟、球员状态机、`BallRuntimeSystem` 与比赛配置。
- 来源：[球员基本行为1](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)、[模块接口](https://app.notion.com/p/3fdf67bb9cfa81fda193e99f0a78e2e6)。
- 足球攻击、空中射门、头球及门将扑救仍由既有 `complete-ai-match-demo` 记录，本次不改变其进度。
