# Design

## Notion 设计依据

- [静态数据层：球员 CSV 读取](https://app.notion.com/p/3e6f67bb9cfa81f69c0cd54264392704)
- [球员属性](https://app.notion.com/p/3e4f67bb9cfa8030be6bff06ef2a0ccc)、[资源规范](https://app.notion.com/p/3e1f67bb9cfa811bbe09e84d31665668)

专题设计及参数以对应 Notion 页面为维护入口；下文保留本变更范围、实现决策与验收记录。

## Context

补录 Notion 第 1 阶段，完成状态由用户确认，并核对现有源码与测试。全局边界见[程序架构](https://app.notion.com/p/3e6f67bb9cfa819ba789f46ac01e629d)和[模块接口](https://app.notion.com/p/3fdf67bb9cfa81fda193e99f0a78e2e6)。

## Goals / Non-Goals

**Goals:** 固化数据层、运行时和显示坐标之间的已实现边界。
**Non-Goals:** 球队与词条定义表、词条权重、体力消耗以及七项属性的全面判定接入。

## Decisions

1. 使用 `DataRepository.load_all()` 协调三个专用 CSV Repository，仅全部成功后索引；失败清空集合。相较按节点各自读表，此方式避免半加载比赛。
2. `PlayerDefinition`、`FieldDefinition`、`MatchConfigDefinition` 提供只读属性；词条列表返回副本。比赛状态归 `PlayerRuntime`、`BallMatchState`，不在静态定义上写入临时字段。
3. `PlayerRuntimeSystem` 拒绝重复 ID，`BallRuntimeSystem.register_ball()` 拒绝第二个球；`MatchSimulation` 对外协调状态变更。
4. `FieldTransform` 负责比例转换；后续实际贴图使用 `FieldArtProjection`，二者均不改变米制规则。

## Risks / Trade-offs

- 七项属性已能读入不代表七项都参与比赛 → 本次仅登记存储契约，统一判定保留在既有后续特性。
- 球员表保存词条 ID 不代表词条系统完成 → 词条定义与权重由 `add-player-traits` 负责。

## 实现与测试证据

- `tests/unit/test_player_data_repository.gd`：合法/边界数值、词条副本、缺失文件、非法表头、重复 ID、词条校验与索引。
- `tests/unit/test_match_config_data_repository.gd`：配置读取、字段与数值校验。
- `tests/unit/test_player_runtime.gd`、`test_ball_possession.gd`：唯一运行时与唯一足球。
- `tests/unit/test_field_environment.gd`：球场数据与坐标往返。
- 本次为文档补录，已阅读对应实现与测试，未重新运行 Godot 测试。

## Migration Plan

仅新增 OpenSpec 文档，不变更数据 schema、代码或资源；撤销本次新增文档即可回退。
