# M 键刻度不明显：调试记录（2026-10-02）

- 现象：用户按 M 后感觉球场没有出现刻度线。
- 根因：真实模式场景中的 M 键输入、信号连接、球场配置和图层开关均正常；上一版刻度只在边线内侧延伸 0.4 m、宽 1 px。经当前美术投影后，上下边线处长度约 4 px，视觉效果过弱。
- 修复：保留四边每 1 m 刻度，将普通刻度改为 1.1 m / 2 px，主刻度每 5 m 为 2 m / 3 px；增加半透明的每米纵横参考线，所有线段使用 FieldArtProjection 投影。
- 证据：通过真实 game_modes.tscn 场景的无渲染输入诊断，M 键把 are_meter_ticks_enabled 从 false 改为 true。Godot 编辑器解析通过；test_meter_ticks_input.gd、test_meter_ticks_integration.gd 和 test_field_environment.gd 均通过。未做截图或画面渲染验证，遵守 Agents.md 的测试约束。
- 回归测试：tests/unit/test_meter_ticks_integration.gd 验证实际场景中连续按 M 可以开关显示状态。
- 相关但未修改：全量测试中 test_demo_reset.gd 失败；test_pass.gd 因工作区已有的挑传阈值 6 m → 8 m 改动而失败。旧的 test_keyboard_pass_input.gd 有退出资源泄漏告警。这些不属于刻度功能修改。
