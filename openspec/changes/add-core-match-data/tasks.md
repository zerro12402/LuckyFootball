# Tasks

> 已完成补录：对应 Notion 开发顺序第 1 项，2026-10-22。用户确认基础阶段已完成；本次核对实现与已有测试，不声明本轮重新执行测试。

## 1. 静态定义与加载

- [x] 1.1 完成七项球员属性与词条 ID 定义、CSV 校验及 ID 查询；验证依据为 `test_player_data_repository.gd` 的合法、边界、错误数据与副本用例。
- [x] 1.2 完成球场与比赛配置读取及三个集合原子发布；验证依据为 `DataRepository.load_all()` 和 `test_match_config_data_repository.gd`。

## 2. 运行时和坐标

- [x] 2.1 分离静态定义与运行时状态并保证唯一球员 ID、唯一足球；验证依据为 `test_player_runtime.gd`、`test_ball_possession.gd`。
- [x] 2.2 完成米制坐标及显示换算；验证依据为 `test_field_environment.gd` 的坐标往返用例。

## 3. 规格完成记录

- [x] 3.1 补齐本阶段 proposal、design、spec 和完成清单；逐项核对 Notion 阶段与实现边界，使用 OpenSpec 严格校验确认文档结构。
