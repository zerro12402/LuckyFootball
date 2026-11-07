# Design

## Notion 设计依据

- [球场环境](https://app.notion.com/p/3e6f67bb9cfa800ab09af6c732728e4d)：第 6.1～6.3 节记录基础全场镜头；第 6.4 节定义正式比赛默认的局部跟球镜头。
- [球场环境：Field 脚本说明](https://app.notion.com/p/3e6f67bb9cfa81308867ebb0545e6550)

专题设计以对应 Notion 页面为维护入口；下文保留本变更范围、实现决策与验收记录。

## Context

补录第 2 阶段。遵循[程序架构](https://app.notion.com/p/3e6f67bb9cfa819ba789f46ac01e629d)的表现只读边界。早期“简单图形”已经演进为贴图环境。

## Goals / Non-Goals

**Goals:** 固化逻辑尺寸、投影和显示组织的边界。
**Non-Goals（已完成的基础阶段）:** 局部跟球镜头、天气、观众、柔性球网和完整比赛 UI；调试米制网格等尚未实现项也不列入完成范围。正式比赛的局部跟球镜头另按 [球场环境规格](specs/field-environment/spec.md) 中的局部镜头需求验收。

## Decisions

1. `FieldDefinition` 是尺寸来源，`FieldEnvironment` 只组织显示。相较使用贴图像素碰撞，规则始终基于米制数据。
2. 实际画面使用 `FieldArtProjection` 六个锚点适配带透视的球场贴图；`FieldTransform` 保留等比例换算。不能用 32 px/m 直接推导实际镜头的米制范围。
3. `GrassBase`、`GrassPattern`、`FieldMarkings` 分层；`GoalBottom` 为 -5、`WorldActors` 为 0 并启用 Y 排序、`GoalTop` 为 5。左右球门组合贴图，右门镜像。
4. 基础阶段的 `FieldCamera` 固定在球场中心，按 `max(min(width/960, height/540), 0.01)` 等比缩放，项目使用 canvas_items 与 keep。正式比赛默认采用约四分之一球场面积的取景，水平跟随足球并带轻微阻尼，纵向仅在球的平面投影接近取景边缘时补偿，最多跟到边线，预留 48 个世界像素；两端保留球门，重置时立即对准新球位。取景按实际投影多边形面积校准，横向端点计入球门贴图和 16 个世界像素留白。镜头读取足球地面投影与回合序号，水平阻尼半衰期默认 0.08 秒，正式比赛流程测试显式沿用全场镜头。
5. `FieldDebugOverlay` 显示边界、坐标轴和五个锚点，默认关闭。

## Risks / Trade-offs

- 更换球场图可能破坏对齐 → 校准锚点并使用坐标往返测试。
- 固定视口只保证当前球场配置的显示 → 任意超大球场的动态取景不在本次基线中。

## 实现与测试证据

- `tests/unit/test_field_environment.gd`：球场配置、比例转换、六个投影锚点与坐标往返。
- `scenes/match/field_environment.tscn`、`project.godot`：分层、相机与视口配置。
- 基础阶段补录以代码、配置和已有测试为依据。局部镜头阶段通过 `test_field_camera.gd`、`test_formal_scene.gd` 和 `test_demo_modes.gd` 的无头逻辑验证，未执行画面验收。

## Migration Plan

局部镜头仅调整表现层，无运行时数据迁移；关闭正式比赛的 `use_local_camera` 即可回到全场取景。
