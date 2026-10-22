# Proposal

## Why

Notion《Demo入口》第 6 项“进球、出界与重置”已完成，需要补齐最小踢球闭环的结果判定、结算和重置契约。

## What Changes

- 补录完整球体越线、最早交点与左右物理球门计数。
- 补录进球后的球网接触位置、减速反弹、最长运动时长和事件顺序。
- 补录出界延迟结算、自动回合重置、手动重置与重新开始测试。
- 仅新增已完成功能文档，不修改现行代码与参数。

## Capabilities

### New Capabilities

- `goal-out-and-reset`: 最小踢球闭环的边界判定、球网运动与原子重置。

### Modified Capabilities

无。

## Impact

- 依赖前五阶段的数据、移动、带球和射门；环境投影仅作显示，不参加规则判定。
- 已有实现：`MatchRules`、`MatchSimulation`、`BallRuntimeSystem`、`MatchEvent` 和结果显示。
- 来源：[进球、出界与重置](https://app.notion.com/p/3edf67bb9cfa809d98fad6eb2305d2aa)、[模块接口](https://app.notion.com/p/3fdf67bb9cfa81fda193e99f0a78e2e6)。
- 正式球队比分、开球、界外球、角球与终场仍归后续正式比赛特性。
