# Design

## Notion 设计依据

- [球员基本行为1 — 单人与足球交互行为](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)
- 相关接球规则：[F02／F03 抢断与确定性传球拦截](https://app.notion.com/p/403f67bb9cfa81068c13e453251a8b08)

专题设计以对应 Notion 页面为维护入口；下文保留本变更范围、实现决策与验收记录，关联公式页不扩大本阶段范围。

## Context

补录第 4 阶段，采用当前统一控球资格。[球员基本行为1](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)中的 ACTIVE 是设计概念，对应 `ActionState.IDLE`，并不要求移动状态也为 IDLE。

## Goals / Non-Goals

**Goals:** 保证球员球权状态与唯一足球一致，并向第 5、6 阶段提供释放和重置路径。
**Non-Goals:** 抢断夺球、高空争顶、门将抱球以及技巧对带球紧密度的数值映射。

## Decisions

1. `BallRuntimeSystem` 持有唯一 `BallMatchState`；取得球权经统一 `_claim_ball()` 路径完成。相比表现层吸附，逻辑路径能保证清理旧球路和同步球员状态。
2. `_can_control_ball()` 与连续接触条件共同约束可控状态、半径、高度、速度与释放保护。低速射门和反弹球共用规则，不另建所有权机制。
3. `OWNED` 足球每步定位到逻辑控制点。当前实现直接跟随，不是早期建议中的平滑滞后；左右朝向与移动向量分离。
4. `PlayerStateMachine` 对 POSSESSING 使用 0.9 移速倍率；控制点偏移 0.55 米。比赛结算关闭自动控球，避免越线后立即被吸回。

## Risks / Trade-offs

- 连续球路可能单步跨过控球范围 → 现行连续接触求交检查首次合法接触，不只看步末。
- 后续动作扩展可能绕过控球资格 → 复用同一资格与原子提交路径。
- 阶段完成不包含全部七属性接入 → 技巧跟随曲线等仍由后续属性特性负责。

## 实现与测试证据

- `tests/unit/test_ball_possession.gd`：半径边界、远处不接、靠近取得、唯一足球、跟随、0.9 倍率和左右朝向。
- `tests/unit/test_ball_control_eligibility.gd`、`test_unowned_ball_control.gd`：统一资格、球速、高度和重新控球。
- `tests/unit/test_goal_out_reset.gd`：结算与重置期间球权。
- 本轮仅核对源码和已有测试，未重新执行 Godot 测试。

## Migration Plan

只补规格文档，无保存数据或运行时迁移；撤销新增文档即可回退。
