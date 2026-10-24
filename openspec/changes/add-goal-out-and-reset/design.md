# Design

## Notion 设计依据

- [进球、出界与重置](https://app.notion.com/p/3edf67bb9cfa809d98fad6eb2305d2aa)
- 后续正式比赛：[正式比赛状态与流程](https://app.notion.com/p/401f67bb9cfa81c192e2ebf6022b163a)

专题设计以对应 Notion 页面为维护入口；下文保留单人阶段的实现与验收记录，正式比赛生命周期仍由独立变更负责。

## Context

补录第 6 阶段。以当前 `MatchSimulation` 和测试记录结算行为。Notion 专题页早期“出界立即停止”已演进为现行延迟结算：离脚球短暂继续移动，持球出界停止球员；本次不为追溯旧文字修改实现。

## Goals / Non-Goals

**Goals:** 将几何规则、结果提交、后续球网运动和重置划分为可测试职责。
**Non-Goals:** 正式球队比分归属、乌龙球、开球权、界外球/角球/球门球、完整门柱物理和柔性球网。当前左右球门计数不等同于正式比赛胜负结果。

## Decisions

1. `MatchRules.resolve_ball_boundary()` 仅返回连续轨迹的首个越线结果，输入是米制尺寸与球半径，不查询美术节点。相较步末点检测，连续交点防止高速穿线漏判。
2. `MatchSimulation` 提交一次结果并控制结算。按左右物理球门增加计数，事件包含侧别、位置、步号、原因与最后踢球者。避免碰撞节点重复加分。
3. 进球进入 POST_GOAL_MOTION，`BallRuntimeSystem.advance_post_goal_motion()` 求解后网/侧网接触及法向反弹、切向保留；事件依次为 GOAL_SCORED、GOAL_NET_CONTACT、RESET_COMPLETED。达到停止阈值或配置最长时长即重置。
4. 出界等待由 `boundary_reset_delay_seconds` 控制。离脚球可按退出速度继续短暂运动；持球出界冻结相关运动。等待期间锁定输入和自动捡球，暂停不推进等待。
5. `_reset_round()` 协调球员出生点恢复和足球清理。自动回中心，手动回登记初始球位；重新开始测试另清空计数、时钟与本次记录。重置在固定步边界优先处理，避免旧待处理动作复活。
6. 结果 HUD 只消费快照和事件，不作为规则来源；正式球队比分模型属于 `add-formal-match-foundation`。

## Risks / Trade-offs

- 早期专题文字与当前延迟出界行为存在差异 → 在本记录注明当前代码基线，未来同步策划时按现行测试核对。
- 高速球同一步可能碰多网面 → 取首次接触并使用稳定顺序处理剩余时间。
- 进球后继续运动可能重复结算 → 锁定结果阶段，只允许球网响应与重置。

## 实现与测试证据

- `tests/unit/test_match_rules.gd`：触线、左右进球、门柱边缘、高速交点、反向入场、最早边界与角点顺序。
- `tests/unit/test_goal_out_reset.gd`：唯一计数、持球/离脚出界等待、进球后运动、暂停等待、两种手动重置与重放。
- `tests/unit/test_goal_net_motion.gd`：左右后网、上下侧网、首次接触、减速反弹和停止。
- `tests/unit/test_demo_reset.gd`：现有测试模式重置链路。
- 本轮阅读对应源码和用例，未运行 Godot、截图、录屏或离屏渲染测试。

## Migration Plan

只新增已完成规格，不修改旧专题页、代码或参数；撤销新增文档即可回退。
