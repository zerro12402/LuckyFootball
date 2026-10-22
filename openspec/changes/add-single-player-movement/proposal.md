# Proposal

## Why

Notion《Demo入口》第 3 项“单个球员移动”已完成。补齐其规格，明确输入只表达意图、模拟负责位移、表现读取状态的边界。

## What Changes

- 记录移动、左右转向、停止和斜向输入限速。
- 记录固定步长命令处理、稳定球员遍历和只读快照。
- 按现有恒定移速实现补录完成状态，本次不改代码。

## Capabilities

### New Capabilities

- `player-movement`: 单球员移动意图、方向与固定步位移契约。

### Modified Capabilities

无。

## Impact

- 依赖 `core-match-data`；可直接用无场景模拟测试，不依赖球场渲染。
- 已有实现：`scripts/core/player/`、`scripts/core/match/match_action.gd`、`scripts/app/game_loop.gd` 与键盘输入适配器。
- 来源：[Demo入口](https://app.notion.com/p/3e1f67bb9cfa810ca84ec25a5b6f485e)、[球员基本行为1](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)。
