# Design

## Context

补录第 2 阶段。遵循[程序架构](https://app.notion.com/p/3e6f67bb9cfa819ba789f46ac01e629d)的表现只读边界。早期“简单图形”已经演进为贴图环境。

## Goals / Non-Goals

**Goals:** 固化逻辑尺寸、投影和显示组织的边界。
**Non-Goals:** 动态跟随镜头、天气、观众、柔性球网和完整比赛 UI；调试米制网格等尚未实现项也不列入完成范围。

## Decisions

1. `FieldDefinition` 是尺寸来源，`FieldEnvironment` 只组织显示。相较使用贴图像素碰撞，规则始终基于米制数据。
2. 实际画面使用 `FieldArtProjection` 六个锚点适配带透视的球场贴图；`FieldTransform` 保留等比例换算。不能用 32 px/m 直接推导实际镜头的米制范围。
3. `GrassBase`、`GrassPattern`、`FieldMarkings` 分层；`GoalBottom` 为 -5、`WorldActors` 为 0 并启用 Y 排序、`GoalTop` 为 5。左右球门组合贴图，右门镜像。
4. `FieldCamera` 固定中心；当前按 `max(min(width/960, height/540), 0.01)` 等比缩放，项目使用 canvas_items 与 keep。相较动态包围盒，这个方案服务固定默认球场。
5. `FieldDebugOverlay` 显示边界、坐标轴和五个锚点，默认关闭。

## Risks / Trade-offs

- 更换球场图可能破坏对齐 → 校准锚点并使用坐标往返测试。
- 固定视口只保证当前球场配置的显示 → 任意超大球场的动态取景不在本次基线中。

## 实现与测试证据

- `tests/unit/test_field_environment.gd`：球场配置、比例转换、六个投影锚点与坐标往返。
- `scenes/match/field_environment.tscn`、`project.godot`：分层、相机与视口配置。
- 本次阅读代码、配置和已有测试；没有执行截图、录屏、离屏渲染或 Godot 测试。

## Migration Plan

仅补文档，无运行时迁移；删除本次新增文档即可回退。
