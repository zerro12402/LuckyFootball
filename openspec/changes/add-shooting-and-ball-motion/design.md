# Design

## Notion 设计依据

- [球员基本行为1 — 单人与足球交互行为](https://app.notion.com/p/3e4f67bb9cfa805386d0dde63636f1c1)
- 后续选靶：[F11 射门准确性与门内外选靶](https://app.notion.com/p/403f67bb9cfa81f59c69c8d04b340ec5)
- 后续扑救：[F04／F10 射门衰减、门将扑救与结果](https://app.notion.com/p/403f67bb9cfa81999a8ce9f821128e3d)

专题设计及现行公式以对应 Notion 页面为维护入口；下文保留基础射门阶段记录，后续选靶和扑救由各自变更承接。

## Context

补录第 5 阶段。早期单人行为页建议“指定方向踢球”，当前实现和 `test_shot_aims_at_opponent_goal_ignoring_command_direction()` 已明确自动朝对方球门；本规格以现有行为为准。

## Goals / Non-Goals

**Goals:** 固化射门命令、触球帧和独立球路的职责边界。
**Non-Goals:** 扑救概率、射门压力/角度修正、随机散布、空中动作、足球击倒及八类统一对抗。射门属性已有局部接入，不代表统一属性特性完成。

## Decisions

1. `MatchSimulation._try_start_shot()` 从球队登记的进攻球门计算方向；球员 ID、球门和方向检查后转交 `BallRuntimeSystem.try_start_shot()`。
2. 球员状态机维护 SHOOTING 动作阶段，足球系统记录待处理射门，触球时复验持有者与状态，再原子离脚。相较按动画帧回调踢球，这个时序可用固定步测试。
3. 球速使用配置线性属性倍率与力度，力度限幅；零速或小于停止阈值时释放为 LOOSE。触球后登记释放者保护和最后踢球者。
4. `BallShotTrajectory` / 足球系统按同一距离推进平面运动和弧线高度，减速到阈值后清理轨迹。球场边界结果归第 6 阶段，球员碰撞响应归既有对抗特性。
5. 参数来自 `match_configs.csv` 的只读配置，表现层读取快照，不控制球速或释放时机。

## Risks / Trade-offs

- 文档中的旧指定方向与实际自动瞄准不同 → 明确记录当前契约，后续改瞄准时另行更新规格。
- 零力度也是合法射门 → 必须释放球权且保证无旧速度残留。
- 射门与属性接入范围容易混淆 → 本次仅记录已有射门倍率，后续统一有效属性仍由独立特性负责。

## 实现与测试证据

- `tests/unit/test_shot.gd`：无球/无球门拒绝、自动瞄准、零力度、前摇、重复命令、触球与恢复、属性/力度、弧线、停止、重放与暂停。
- `tests/unit/test_demo_shot_integration.gd`、`test_keyboard_shoot_input.gd`：现有测试模式与输入链路。
- `tests/unit/test_unowned_ball_control.gd`：离脚后的重新控球。
- 本轮仅核对源码与现有用例，未重新执行 Godot 测试。

## Migration Plan

仅补文档，不改变现行射门参数或输入语义；撤销新增文档即可回退。
