# Tasks

> 已完成补录：对应 Notion 第 3 阶段，2026-10-22。用户确认已完成；现有源码和测试作为核对依据，本轮未重新运行 Godot 测试。

## 1. 逻辑移动

- [x] 1.1 完成定速固定步移动、方向限长与未知 ID 拒绝；验证依据为 `test_player_movement.gd`。
- [x] 1.2 完成方向持续、零方向停止与左右朝向更新；验证依据为移动测试及 `test_ball_possession.gd` 的左右朝向保持用例。
- [x] 1.3 完成命令到固定步推进、稳定 ID 遍历及快照输出；验证依据为 `test_game_loop.gd` 与 `test_player_runtime.gd`。

## 2. 规格记录

- [x] 2.1 补齐 proposal、design、spec 和完成清单；核对当前实现与早期建议的差异，并通过 OpenSpec 严格校验。
