# Design

## Notion 设计依据

- [球员基本行为1 — 单人与足球交互行为](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)
- 后续属性接入：[F01 移动速度与追逐](https://app.notion.com/p/403f67bb9cfa812aac51ebeb876e9718)、[F01 速度属性与等比移动 — 程序设计](https://app.notion.com/p/401f67bb9cfa81e9919cc3e8b160abf7)

专题设计及现行公式以对应 Notion 页面为维护入口；下文保留本阶段基线，不将后续属性接入追记为本阶段完成内容。

## Context

补录第 3 阶段。根据现有状态机与测试登记完成基线，而非把早期建议中的加减速、八方向朝向和速度属性映射一并宣称完成。

## Goals / Non-Goals

**Goals:** 明确移动命令、米制位移、左右朝向和表现读取的边界。
**Non-Goals:** 加减速曲线、急转减速、速度属性全面接入及体力修正；本能力不承诺普通移动在边线处被钳制。

## Decisions

1. 输入生成 `MatchAction.Type.MOVE`，`PlayerRuntime.apply_action()` 转交 `PlayerStateMachine.set_movement_input()`；相较输入直接移动 Node，模拟结果可无场景验证。
2. `limit_length(1.0)` 限制方向长度，零输入立即进入 IDLE；非零输入按登记移速乘固定步直接积分。当前没有加速度和减速度阶段。
3. 移动向量与左右表现朝向分离；有 X 分量时更新朝向，纯竖直移动保留原朝向。带球控制点依赖同一逻辑朝向。
4. `GameLoop` 累计时间并调用 `MatchSimulation.advance_fixed_step()`；`PlayerRuntimeSystem.get_players()` 稳定按 ID 排序，不依赖场景树顺序。
5. 持球 0.9 倍移速在第 4 阶段规格登记；本阶段的基本位移示例使用无球状态。

## Risks / Trade-offs

- 单人行为早期文档包含尚未落地的平滑运动和速度属性映射 → 本次完成范围以源码测试为准，全面属性映射归 `integrate-player-attributes-and-contests`。
- 逻辑左右朝向不同于完整移动向量 → 表现和带球均读取明确字段，测试保留纯竖直移动的左右朝向。

## 实现与测试证据

- `tests/unit/test_player_movement.gd`：定速移动、意图持续、停止、斜向限速与未知 ID。
- `tests/unit/test_ball_possession.gd`：左转后上/下移动保持左右朝向。
- `tests/unit/test_player_runtime.gd`、`test_game_loop.gd`：稳定 ID、固定步累计与重放。
- 本次阅读已有测试与实现，没有重新执行 Godot 测试。

## Migration Plan

仅新增完成记录，不调整现行运动或动画行为；撤销新增文档即可回退。
