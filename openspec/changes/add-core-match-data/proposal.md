# Proposal

## Why

Notion《Demo入口》开发顺序第 1 项“最小数据结构”已经完成，但缺少可追溯的 OpenSpec 规格。本变更于 2026-10-22 补录已实现的数据与坐标契约，作为后续功能的基础。

## What Changes

- 记录球员七项基础属性、词条 ID 列表、球场和比赛配置的统一 CSV 读取。
- 记录只读静态定义、独立运行时状态、唯一足球和米制坐标。
- 补齐对应规格、实现设计和已完成任务；本次只新增文档。

## Capabilities

### New Capabilities

- `core-match-data`: 最小静态数据、运行时状态和坐标契约。

### Modified Capabilities

无。

## Impact

- 已有实现：`scripts/core/data/`、`scripts/core/player/player_runtime.gd`、`scripts/core/ball/ball_match_state.gd`、`scripts/core/field/field_transform.gd`。
- 数据：`resources/data/players.csv`、`fields.csv`、`match_configs.csv`。
- 后续第 2–6 阶段依赖本能力。七项属性全面参与判定仍属于 `integrate-player-attributes-and-contests`。
- 来源：[Demo入口](https://app.notion.com/p/3e1f67bb9cfa810ca84ec25a5b6f485e)、[模块接口](https://app.notion.com/p/3fdf67bb9cfa81fda193e99f0a78e2e6)。
