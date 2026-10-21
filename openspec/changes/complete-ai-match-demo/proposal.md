# Proposal

## Why

比赛基础动作与对抗需要先在共用测试模式中稳定验证，才能支撑后续属性、6V6 正式比赛和全 AI。按本轮拆分，本变更保留原名称，集中完成前四组动作及其联动；其余功能分别成为可独立验收的特性。

## What Changes

- **已有基础**：球场、固定步、移动、控球、传射、进球/出界、球网、重置与比分；部分抢断、近身攻击和测试 AI 已实现。
- 保留带球起跳、空中射门、高空争顶、头球攻门/解围、足球击倒及门将抱球/扑出的规则与共用测试模式。前两组及 3.1 文档已完成，具体进度以 tasks.md 为准。
- 足球击倒仍比较锁定射门基础值与目标强壮度，严格大于才倒；击倒后 50%/50% 继续或反弹，未倒必反弹，接触与球路结果分开。
- 将原第 5 组迁至 integrate-player-attributes-and-contests，第 6 组迁至 add-formal-match-foundation；原第 7 组拆为 add-player-ai 与 add-player-traits。
- 保留动作间的无场景联动验收；正式入口、只读终场输出与完整自动比赛由新特性分别交付，不重复在本变更追踪。
- 功能策划写对应 Notion 设计页，程序设计写《程序架构》子页；全局架构和接口用于核对边界。测试继续共用现有模式，不新增单项场景。

## Capabilities

### New Capabilities

- `aerial-play`：带球起跳、空中射门、争顶与头球攻门/解围。
- `goalkeeper-saves`：合法站位/扑救动作、抱球与扑出规则。
- `ball-impact-contests`：射门接触、闪避、击倒与临时球路响应。

### Modified Capabilities

无；主规格尚为空。原 autonomous-match 草案按职责迁入四个独立特性，不再在本变更中重复发布。

## Impact

影响既有球员、足球、模拟规则、事件/快照、配置及共用测试模式。规则可通过显式属性和测试命令独立验证，不等待正式场景或完整 AI。

后续特性依次为 [属性与统一判定](../integrate-player-attributes-and-contests/proposal.md)、[正式比赛基础](../add-formal-match-foundation/proposal.md)、[球员 AI](../add-player-ai/proposal.md)、[词条](../add-player-traits/proposal.md)。下注挑战从正式比赛基础读取时钟、比分与终场结果，并在全 AI/词条就绪后完成最终体验集成。
