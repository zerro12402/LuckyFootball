# 幸运足球球员 AI 脚本手册 · 接口 v2

## 一份脚本绑定一支球队

1. 打开画面左下角 **球员 AI Lab**，粘贴下方 JSON 并点 **校验脚本**。
2. 点 **绑定并试跑**。v2 自动绑定蓝队，沿用当前正式比赛的种子。
3. 每名球员在自己的决策点独立运行同一份编译结果。对手使用内置 AI。再点左下角 **球员 AI Lab** 或按 **Esc** 可关闭编辑器。
4. 运行时若当前行为或目标非法，界面显示对应球员和最近一次回退原因。其他球员照常运行。

v1 仍使用 [v1 手册](player-ai-script-v1.md) 的蓝队单前锋流程。v2 继承 v1 的语法、字段及预算。顶层改为 `"version": 2`；按顺序选择第一条全部满足的规则，未命中使用 `default`。可返回 `{}`、`{"weights":{"pass":2}}`，或 `{"behavior":"pass","target":"first"}`。脚本只读值数据，不读随机数或写比赛状态。源码上限 8192 UTF-8 字节、8 层 JSON、24 条规则、每条最多 8 个条件、每次最多 128 次比较。

## v1 字段速查

- `self.id` 为球员 ID。 `self.x`、`self.y`、`self.goal_distance_m` 是米制数值，X 正向朝本队进攻球门，Y 正向朝画面下方。`self.owns_ball`、`self.pressured` 为布尔值。
- `ball.x`、`ball.y`、`ball.height_m` 单位为米，`ball.vx`、`ball.vy` 单位为米每秒。`ball.owner_id` 为持球者 ID，无人时为空串。
- `phase` 为 `attack`、`defend` 或 `loose`。`teammate_count`、`opponent_count` 是人数。`nearest_teammate_m`、`nearest_opponent_m` 是最近距离，没有目标时为 -1。
- 条件写作 `["字段","比较符",值]`。数字支持 `== != < <= > >=`，字符串与布尔值只支持 `== !=`。

## v2 新字段

| 字段 | 类型与取值 |
| --- | --- |
| `self.role` | 字符串，`forward`、`mid`、`back`、`keeper` |
| `self.position` | 字符串，`forward_left`、`forward_right`、`mid`、`back_left`、`back_right`、`keeper` |
| `self.duty` | 字符串，`carrier` 持球、`receiver` 接球目标、`press` 主防、`chase` 主争球、`goalkeeper` 守门或 `positioning` 常规跑位 |
| `ball.relation` | 字符串，`self`、`teammate`、`opponent`、`none` |
| `ball.source` | 字符串，`none`、`pass`、`shot`、`clearance`、`roll`，表示当前球路类型 |
| `ball.last_kicker_id` | 字符串，最近踢球者 ID，没有时为空串 |
| `has.<行为>` | 布尔值，当前是否有该行为和合法目标 |
| `has_target.<行为>.<目标>` | 布尔值，例如 `has_target.pass.formal_player_02` 或 `has_target.keeper_save.center`；`first` 表示至少有一个合法目标 |

## v2 行为与目标

外场保留 v1 的 `hold`、`dribble`、`pass`、`shoot`、`support`、`run_forward`、`press`、`tackle`、`chase`、`return`。新行为只有当前候选满足资格时可用。

- 中场可用 `drop_support` 向持球者身后接应、`central_support` 支援中路。后卫可用 `back_support` 在后方接应、`mark` 在对手与本方球门之间盯防、`protect_goal` 在防区内横向保护球门。中场和后卫都可用 `cover_lane` 在站位和威胁之间封线。目标由游戏计算并限制在职责区域，封线只决定跑位。
- `jump` 使用现有起跳动作，`air_shoot` 使用合法的持球空中射门。`header_shot`、`header_clear` 在高空传球可达时准备头球；实际触球仍按固定步判定。`attack` 使用现有近身攻击及其对抗规则。
- 门将只开放 `keeper_position`、`keeper_slide`、`keeper_save`、`hold`、`pass`。站位回到门口中点，横移沿门口跟踪球的横向偏移，两者都由游戏限制在门口范围内，扑救候选只在现有窗口出现，目标为 `upper`、`center`、`lower` 或 `first`。持球传球原地进行。
- `pass`、`tackle`、`attack` 目标是合法球员 ID 或 `first`。移动、起跳、射门和头球目标用空串。射门目标由比赛规则决定。共用同一计划的别名不能在一条 `weights` 中重复加权。

## 四位置完整示例

```json
{
  "version": 2,
  "rules": [
    {"when":[["self.role","==","keeper"],["has.pass","==",true]],"then":{"behavior":"pass","target":"first"}},
    {"when":[["self.role","==","keeper"],["has.keeper_save","==",true]],"then":{"behavior":"keeper_save","target":"first"}},
    {"when":[["self.role","==","keeper"],["has.keeper_position","==",true]],"then":{"behavior":"keeper_position","target":""}},
    {"when":[["self.role","==","forward"],["has.shoot","==",true],["self.goal_distance_m","<",7]],"then":{"weights":{"shoot":2}}},
    {"when":[["self.role","==","mid"],["phase","==","attack"],["has.central_support","==",true]],"then":{"behavior":"central_support","target":""}},
    {"when":[["self.role","==","back"],["phase","==","defend"],["has.protect_goal","==",true]],"then":{"behavior":"protect_goal","target":""}}
  ],
  "default": {}
}
```

## 给生成式 AI 的提示词

> 只使用这份《幸运足球球员 AI 脚本手册 · 接口 v2》。按我的战术〔填写要求〕生成一份完整的 version 2 JSON，由一支球队所有球员共享。按 self.role 和局面分支，先检查 has 或 has_target，再选择或调整合法候选。为缺少匹配的局面提供默认回退。