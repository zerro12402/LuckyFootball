# Tasks

> 已完成补录：对应 Notion 第 5 阶段，2026-10-22。用户已确认阶段完成，本次核对已有代码与测试，不声明本轮重新运行测试。

## 1. 射门动作与球路

- [x] 1.1 完成射门资格、进攻球门方向与命令拒绝路径；验证依据为 `test_shot.gd` 的前提和自动瞄准用例。
- [x] 1.2 完成前摇、一次触球释放、后摇与中断清理；验证依据为 `test_shot.gd`、`test_goal_out_reset.gd`。
- [x] 1.3 完成射门属性与力度映射、独立弧线及减速停止；验证依据为 `test_shot.gd` 的球速、顶点、停止、重放和暂停用例。
- [x] 1.4 完成现有共用测试模式中的射门输入和联动；验证依据为 `test_keyboard_shoot_input.gd`、`test_demo_shot_integration.gd`，不新增独立场景。

## 2. 规格记录

- [x] 2.1 补齐 proposal、design、spec 和完成清单；明确自动瞄准与早期建议的差异，通过 OpenSpec 严格校验。
