# Proposal

## Why

Notion《Demo入口》第 4 项“持球与带球”已完成，需要补齐球权和带球行为的可验证契约，供射门和重置复用。

## What Changes

- 补录自动获取低速无主球、球权原子变更和持球跟随。
- 纳入现行统一控球资格与释放者保护规则，避免重复定义接球机制。
- 完成记录仅覆盖单人与足球的基础交互，本次不改实现。

## Capabilities

### New Capabilities

- `ball-possession-and-dribbling`: 唯一球权、基础自动控球与确定性带球。

### Modified Capabilities

无。

## Impact

- 依赖 `core-match-data` 与 `player-movement`。
- 已有实现：`scripts/core/ball/ball_runtime_system.gd`、`ball_match_state.gd`、球员状态机和比赛模拟。
- 来源：[球员基本行为1](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)、[模块接口](https://app.notion.com/p/3fdf67bb9cfa81fda193e99f0a78e2e6)。
- 高空争顶、扑救和抢断不属于本次基础球权规格。
