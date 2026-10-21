# Proposal

## Why

现有 TackleChaseAI 只服务一名测试对手，不能控制双方十二人完成比赛。球员 AI 需要成为独立特性，以快照和动作协议验证攻防决策，并在词条系统接入前完成基础全 AI 比赛。

## What Changes

- 接收 `complete-ai-match-demo` 原 7.1、7.3，以及 7.2 中的状态动作限制；词条权重迁至 `add-player-traits`。
- 建立所有场上球员的持球、无球、攻防和门将动作候选，覆盖传射、起跳/空中动作、争顶、抢断、攻击与扑救。
- 快照驱动决策，位置、体力与状态影响候选和基础行为权重；模拟层继续校验和提交所有动作。
- 为后续词条提供行为权重扩展接口，默认中性输入即可独立运行。
- 接入正式比赛并完成十二人固定种子整场验收，不要求玩家操控球员。

## Capabilities

### New Capabilities

- `player-ai`：快照驱动的双方全 AI、合法动作候选、门将决策和整场自动推进。

### Modified Capabilities

无；接收原未发布自主比赛规格中的 AI 部分。

## Impact

依赖 `add-formal-match-foundation` 和 `integrate-player-attributes-and-contests`。影响 AI、GameLoop 的动作来源接入和正式装配；原测试 AI 保持测试用途。词条定义、Demo 随机词条生成和下注不在本特性内。
