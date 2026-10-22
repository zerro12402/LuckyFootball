# Tasks

> 已完成补录：对应 Notion 第 6 阶段，2026-10-22。用户确认已完成，本轮核对现有源码与测试，没有重新执行 Godot 测试。

## 1. 边界与结果

- [x] 1.1 完成整球越线、连续交点、门口范围及最早边界判定；验证依据为 `test_match_rules.gd`。
- [x] 1.2 完成左右球门唯一计数、出界结果和动作锁定；验证依据为 `test_goal_out_reset.gd` 的双侧进球、非门口出界与等待用例。

## 2. 球网与结算

- [x] 2.1 完成进球后后网/侧网接触点、配置减速和反弹；验证依据为 `test_goal_net_motion.gd`。
- [x] 2.2 完成进球停止/超时重置、出界延迟与暂停等待；验证依据为 `test_goal_out_reset.gd` 的运动、时限和暂停断言。

## 3. 重置闭环

- [x] 3.1 完成自动回中心、手动回初始球位、出生点/动作/球权清理，以及保留计数和重新开始的区别；验证依据为 `test_goal_out_reset.gd`、`test_demo_reset.gd`。
- [x] 3.2 完成重置后再次控球和射门的最小闭环；验证依据为同一模拟重置后获得球权的用例与 `test_demo_shot_integration.gd`。
- [x] 3.3 补齐 proposal、design、spec 和完成清单；核对当前延迟结算与 Notion 来源，通过 OpenSpec 严格校验。
