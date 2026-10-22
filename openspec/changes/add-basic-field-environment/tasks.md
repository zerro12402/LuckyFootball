# Tasks

> 已完成补录：对应 Notion 第 2 阶段，2026-10-22。完成依据为用户确认与现有实现；本轮未执行画面或 Godot 测试。

## 1. 球场显示

- [x] 1.1 完成默认球场定义与显示投影；验证依据为 `test_field_environment.gd` 的尺寸、锚点及坐标往返用例。
- [x] 1.2 完成外围、草地、场线、中线、球门和角色容器；通过 `field_environment.tscn` 中资源引用、Y 排序与层级核对实现。
- [x] 1.3 完成固定全场镜头及等比适配、可关闭的边界/轴/锚点调试叠加；通过 `FieldEnvironment`、`FieldDebugOverlay` 与 `project.godot` 的配置和计算核对。

## 2. 规格记录

- [x] 2.1 补齐 proposal、design、spec 和完成清单；核对 Notion 当前球场设计并通过 OpenSpec 严格校验。
