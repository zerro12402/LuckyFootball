# Proposal

## Why

Notion《Demo入口》第 2 项“基础场景绘制”已完成，需要补齐其 OpenSpec 基线，使逻辑球场、环境显示和镜头适配具有明确契约。

## What Changes

- 补录米制球场到贴图的映射、球场和球门分层、角色容器与固定全场镜头。
- 以现有贴图实现替代早期简单图形方案的完成记录；不改变当前资源。
- 本次仅新增文档，完成状态依据用户确认和现有实现。

## Capabilities

### New Capabilities

- `field-environment`: 球场环境显示、坐标投影与镜头覆盖。

### Modified Capabilities

无。

## Impact

- 依赖第 1 阶段 `core-match-data`。
- 已有代码：`scripts/presentation/field/`、`scripts/core/field/`。
- 场景：`scenes/match/field_environment.tscn`；角色：`scenes/actors/player_actor.tscn`、`ball_actor.tscn`。
- 来源：[球场环境](https://app.notion.com/p/3e6f67bb9cfa800ab09af6c732728e4d)、[Demo入口](https://app.notion.com/p/3e1f67bb9cfa810ca84ec25a5b6f485e)。
