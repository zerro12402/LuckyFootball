# Proposal

## Why

球员表已保存每人 3–5 个词条 ID，但缺少词条定义的加载、跨表校验和对 AI 行为权重的实际影响。将词条独立出来，可先验证基础 AI，再测试同一局面下不同词条带来的行为差异。

## What Changes

- 接收 `complete-ai-match-demo` 原 7.2 的词条权重与 Demo 覆盖接口部分。
- 建立 traits.csv 定义和只读模型，校验稳定 ID、球员引用与每人 3–5 个合法不重复词条。
- 以配置条件和权重修改 AI 候选行为，不引入显式 Combo，不直接修改基础属性、球权、比分或对抗结果。
- 正式模式取 players.csv；Demo 可注入合法的本轮词条覆盖，保持来源隔离和运行期稳定。
- 本特性提供定义、候选条件和覆盖接口；总种子派生、随机生成及五场持久化仍归 `add-five-match-betting-challenge`。

## Capabilities

### New Capabilities

- `player-traits`：词条定义、分配校验、行为权重组合及正式/Demo 来源隔离。

### Modified Capabilities

无；接收原未发布自主比赛规格中的词条部分。

## Impact

依赖 `add-player-ai` 的候选行为与权重接口；数据加载可用独立测试推进。影响静态数据仓库、词条模型、AI 权重扩展和正式装配；下注挑战复用这些定义与接口，不重复创建词条加载器。
