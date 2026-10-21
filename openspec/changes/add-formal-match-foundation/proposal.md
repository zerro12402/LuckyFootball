# Proposal

## Why

当前正式比赛场景仍是空节点，缺少合法 6V6 阵容装配、可配置比赛时长和唯一终场结果。将这些基础从动作、AI 和词条中拆出，可独立验证比赛生命周期和只读接口。

## What Changes

- 接收 `complete-ai-match-demo` 原第 6 组任务与原 autonomous-match 中的阵容、入口、计时和输出需求。
- 建立球队/阵容 CSV 及校验，双方各六人且每队一名门将，人数和 ID 不合法时拒绝启动。
- 将既有比赛规则与表现装入正式场景，保持唯一球权与正式/开发测试入口边界。
- 使用固定步模拟时间产生唯一终场事件和冻结赛果，并提供不可变阶段、时间、比分、种子与比赛标识。
- 定义通用动作来源装配点，用预设动作独立验收；完整自主踢球由 `add-player-ai` 接入，正式入口不接收键盘操控球员。

## Capabilities

### New Capabilities

- `formal-match`：合法 6V6 比赛装配、正式入口、计时终场和只读输出。

### Modified Capabilities

无；接收原未发布自主比赛规格中的基础部分。

## Impact

依赖 `complete-ai-match-demo` 和 `integrate-player-attributes-and-contests`。影响球队/阵容数据、MatchState、MatchSimulation、正式场景与装配测试；只读接口由下注挑战直接消费，不承担 AI、词条或筹码规则。
