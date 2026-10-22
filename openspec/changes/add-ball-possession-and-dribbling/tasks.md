# Tasks

> 已完成补录：对应 Notion 第 4 阶段，2026-10-22。依据用户完成确认和现有实现/测试；本轮没有重新执行 Godot 测试。

## 1. 控球和带球

- [x] 1.1 完成自动控球资格、半径和唯一持有者状态变更；验证依据为 `test_ball_possession.gd` 与 `test_ball_control_eligibility.gd`。
- [x] 1.2 完成逻辑控制点跟随、左右转向与持球移速倍率；验证依据为 `test_ball_possession.gd` 的跟随和速度断言。
- [x] 1.3 完成低速无主球重获、释放者保护与结算时禁控球；验证依据为 `test_unowned_ball_control.gd` 和 `test_goal_out_reset.gd`。

## 2. 规格记录

- [x] 2.1 补齐 proposal、design、spec 和完成清单；核对最新 Notion 统一控球规则，通过 OpenSpec 严格校验。
