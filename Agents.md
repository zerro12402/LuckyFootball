# 幸运足球项目规范

本文件适用于本项目的代码、场景、资源与数据修改。以下内容同步自 Notion「幸运足球 / 规范」，保留原规范要求。

- 同步日期：2026-09-23
- 规范入口：https://app.notion.com/p/3e1f67bb9cfa81d6ae8ef4a8ed6b1871

## 代码规范

来源：[Notion 代码规范](https://app.notion.com/p/3e1f67bb9cfa819bbcb9e5f6a83f7a88?pvs=204)  
源页面最后编辑时间：2026-09-20T16:31:16.560Z

### 适用范围
本规范适用于「幸运足球」项目所有 Godot 4.x GDScript。目标是让比赛逻辑可读、可测试、可复现，并让场景表现层不干扰核心规则。
### 基本原则
- 使用 Godot 4 与 GDScript 2.0；不为兼容旧版 Godot 写分支代码。
- 每个脚本只负责一个明确职责。比赛规则、AI、输入、绘制和 UI 不混在同一脚本中。
- 规则层不依赖 `Node`、`SceneTree`、`Input`、`Timer` 或具体场景路径；它只接收数据并返回结果或事件。
- 场景层负责节点、动画、音效和显示；它读取比赛状态与事件，不在这里决定比赛规则。
- 不在核心逻辑中使用未控制的 `randf()`、`randi()` 或真实时间。随机数和模拟时间必须由外部注入，便于复现测试。
- 先写清输入、输出和状态变化，再实现代码；避免通过隐式节点状态传递规则。
### 文件与目录
- 一个主要类对应一个 `.gd` 文件，文件名使用 `snake_case`：`ball_motion.gd`、`match_state.gd`。
- 场景文件使用与根节点职责一致的 `snake_case` 名称：`match_field.tscn`、`match_hud.tscn`。
- 核心代码与表现代码分层：`scripts/core/`、`scripts/simulation/`、`scripts/presentation/`、`scripts/ui/`、`tests/`。
- 可复用资源、配置和测试样本分别放入 `resources/`、`config/`、`tests/fixtures/`；不要把临时调试数据写进正式场景。
### 命名
| 对象 | 规则 | 示例 |
| --- | --- | --- |
| 类与 `class_name` | PascalCase | `class_name MatchState` |
| 文件、变量、函数、信号 | snake_case | `ball_velocity`、`resolve_tackle()`、`goal_scored` |
| 常量 | SCREAMING_SNAKE_CASE | `const MAX_TEAM_SIZE := 6` |
| 私有成员 | 前缀 `_` | `_rng`、`_advance_ball()` |
| 布尔值 | 以 `is_`、`has_`、`can_`、`should_` 开头 | `is_knocked_down`、`can_shoot` |
| 枚举 | PascalCase 类型名，值用 SCREAMING_SNAKE_CASE | `enum MatchPhase { KICKOFF, PLAYING, FINISHED }` |

- 函数名用动词开头：`apply_stamina_cost()`、`calculate_shot_quality()`。
- 避免含糊名称，如 `data`、`value`、`handle()`、`process()`；名称应表达领域含义。
- 信号描述已经发生的事件，使用过去式或完成态：`goal_scored`、`player_knocked_down`、`match_finished`。
### 类型与数据
- 所有成员变量、参数、返回值和容器元素均标注类型；仅在 Godot API 无法准确表达时例外。
- 使用 `:=` 让编译器推导显而易见的局部值；不依赖 `Variant` 作为通用数据袋。
- 领域数据优先使用 `class_name` 的 `RefCounted` 数据类或 `Resource`，不要用无类型 `Dictionary` 传递球员、动作或判定结果。
- 用 `enum` 表示有限状态；不要以字符串切换比赛阶段、动作类型或球权状态。
- 对外公开的数组与字典要么返回副本，要么明确只读约定，避免调用方绕过规则修改比赛状态。
```gdscript
class_name ShotResult extends RefCounted

var is_goal: bool
var was_saved: bool
var final_ball_velocity: Vector2
var events: Array[MatchEvent] = []

func _init(
	goal: bool,
	saved: bool,
	velocity: Vector2,
	new_events: Array[MatchEvent],
) -> void:
	is_goal = goal
	was_saved = saved
	final_ball_velocity = velocity
	events = new_events
```
### 格式与结构
- 使用制表符缩进，遵从 Godot 编辑器的默认格式化风格。
- 单行目标长度建议不超过 100 个字符；长参数列表每行一个参数并保留尾随逗号。
- 一个脚本内的成员顺序：`class_name` → `extends` → 信号 → 枚举 → 常量 → 导出变量 → 公共变量 → 私有变量 → `_init` / 生命周期函数 → 公共函数 → 私有函数。
- 函数尽量短；超过约 40 行时优先提炼与领域概念对应的私有函数。
- 注释解释设计原因、规则意图或非直观约束，不逐行复述代码。
### Godot 节点与场景
- 使用唯一节点名与 `%NodeName` 引用同一场景内的必需节点；不要依赖脆弱的相对路径如 `../../Player`。
- `@onready` 只缓存表现层需要的节点；核心规则类不得保存节点引用。
- `@export` 仅用于设计师需要在 Inspector 中配置的参数。影响公平性或可复现性的比赛参数应集中在版本化配置资源中。
- 不在 `_process(delta)` 中做比赛规则判定。模拟推进使用固定步长，例如 `advance_simulation(fixed_delta)`；`_process` 只负责驱动、插值或展示。
- 不使用 `get_tree().get_nodes_in_group()` 作为核心规则查询。由比赛状态维护明确的球员集合与索引。
### 输入、AI 与比赛逻辑边界
- 人类键盘输入和 AI 都先转换为同一种 `PlayerCommand` 或 `MatchAction`，再交给模拟层执行。
- AI 负责提出动作和权重；模拟层负责检查距离、冷却、球权、倒地和规则合法性。AI 不能直接改比分、球位置或他人的状态。
- 词条和状态只能修改行为权重、可选动作或明确的规则修正；不得在 UI 脚本中偷偷改变判定结果。
- 一次对抗应产生结构化事件与结果，例如命中、闪避、击倒、反弹；不要仅用打印文本作为规则输出。
### 随机性、时间与可复现性
- 每场比赛持有一个明确种子的 `RandomNumberGenerator`，种子写入比赛记录。
- 所有随机判定通过注入的随机源调用；单元测试可传入固定随机源或固定抽样值。
- 模拟层接收 `fixed_delta` 和当前比赛时间，不读取系统时间。
- 相同初始状态、配置、命令序列和随机种子必须得到相同事件序列。
### 错误处理与调试
- 不能继续的开发期不变量使用 `assert()`，例如球员编号重复、体力越界或无效阵容。
- 面向运行时的异常状态应返回明确失败结果或事件；不要静默吞掉错误。
- `print()` 仅限临时本地排查，提交前删除；正式调试信息进入统一的 `MatchEvent` / 调试记录。
- 禁止为绕过错误而使用 `@warning_ignore`，除非在紧邻位置说明原因与移除条件。
### 单元测试
- 核心规则优先使用无场景、无节点的单元测试。一个测试只验证一个业务事实。
- 测试名称使用「前提_动作_预期」：`test_tired_player_when_sprinting_consumes_more_effective_capacity()`。
- 每个新增规则至少覆盖：正常结果、边界条件、非法输入或不可执行条件、固定随机结果。
- 对随机对抗测试传入固定种子或伪随机源，不以概率分布测试替代确定性规则测试。
- 每个阶段增加少量联动测试：例如「带球 → 射门 → 球权释放 → 球独立运动」。UI 用场景测试或手动检查，不替代核心规则单元测试。
### 提交前检查
- 脚本无解析错误与无新增警告。
- 新增或修改的核心规则已有对应单元测试。
- 相同种子下的比赛测试可复现。
- 场景脚本未包含本应属于模拟层的判定或直接状态改写。
- 调试打印、硬编码场景路径和临时键盘逻辑未进入正式比赛路径。

## 资源规范

来源：[Notion 资源规范](https://app.notion.com/p/3e1f67bb9cfa811bbe09e84d31665668?pvs=204)  
源页面最后编辑时间：2026-09-20T16:52:30.380Z

### 适用范围
本规范适用于「幸运足球」项目中所有非代码资源，包括场景、贴图、精灵图、音频、字体、主题、动画、数据资源与测试样本。目标是使资源可定位、可替换、可复用，并避免原型阶段的临时文件进入正式内容。
### 基本原则
- 资源按用途和归属组织，不按下载来源或创作者姓名组织。
- 一个资源应有唯一、稳定且能表达用途的名称；禁止保留 `New Sprite`、`image_001`、`final_final` 等临时命名。
- 原始素材与游戏运行资源分开保存。原始文件不能直接作为运行时唯一来源。
- 先复用已有资源，再创建重复副本；变体应通过明确后缀、主题或配置表达。
- 美术和音频只负责表现，不携带比赛规则数值。射门力度、碰撞范围、倒地时长等规则数据放在配置资源中。
- 进入版本控制的资源必须可被项目在另一台机器上重新导入和引用。
### 推荐目录
```text
res://
├── assets/
│   ├── art/
│   │   ├── characters/
│   │   ├── field/
│   │   ├── ball/
│   │   ├── ui/
│   │   └── vfx/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   ├── fonts/
│   └── source/              # 可追溯的源文件，非运行时直接依赖
├── scenes/
│   ├── match/
│   ├── ui/
│   ├── actors/
│   └── test/
├── resources/
│   ├── config/
│   ├── data/
│   │   ├── players.csv
│   │   ├── teams.csv
│   │   ├── team_players.csv
│   │   ├── traits.csv
│   │   ├── states.csv
│   │   └── match_configs.csv
│   └── themes/
├── tests/
│   └── fixtures/
└── docs/
```
- `assets/source/` 存放 PSD、Aseprite、SVG 源稿或原始录音等可编辑来源；导出的 PNG、OGG、MP3 等运行资源放入对应分类目录。
- `resources/data/` 是所有可表格化静态游戏数据的唯一来源；球员、球队、阵容归属、词条、状态与比赛配置分别使用关联 CSV 表。所有规则数据都不能塞入脚本常量或场景节点属性。
- `scenes/test/` 与 `tests/fixtures/` 只服务测试和调试，不得被正式比赛入口引用。
### 文件命名
| 资源类型 | 格式与规则 | 示例 |
| --- | --- | --- |
| 通用文件名 | 全小写 `snake_case`，使用英文领域名 | `ball_shadow.png` |
| 场景 | 职责名 | `match_field.tscn`、`player_actor.tscn` |
| 配置资源 | 实体或用途 + `_config` | `prototype_match_config.tres` |
| 球员数据表 | 单一 CSV，表头使用 `snake_case` 字段名 | `players.csv` |
| 球队与阵容数据 | 关联 CSV 表，以稳定 ID 建立关系 | `teams.csv`、`team_players.csv` |
| 词条、状态与比赛配置 | 表格化静态规则数据 | `traits.csv`、`states.csv`、`match_configs.csv` |
| 精灵图 | 对象 + 动作 + 可选方向 | `striker_run_right.png` |
| 音效 | 动作 + 材质或变体 | `kick_ball_hard_01.ogg` |
| 音乐 | 场景或情绪 | `match_tension_loop.ogg` |
| UI 图标 | 功能或语义 | `icon_pause.svg` |

- 使用数字变体时至少补两位：`_01`、`_02`，并只用于真正可互换的素材变体。
- 不把尺寸、日期、作者名写入正式运行文件名，除非它们区分运行时用途。
- 不使用中文、空格或大小写差异作为资源路径的唯一差别，避免跨平台路径问题。
### 贴图、精灵图与图标
- UI 图标优先使用 SVG；像素风或需要严格像素控制的角色和场景使用 PNG。
- 贴图尺寸遵循实际显示需求，避免把超大图缩小显示。非必要不超过 2048 px 边长。
- 透明贴图使用 PNG 或 WebP，并检查透明边缘是否出现色边。
- 同一角色的精灵图保持统一的基准点、像素密度、朝向规则与动画帧率。
- 角色、足球、球门与场地的碰撞形状由场景或配置定义，不从贴图透明区域自动推断。
- 原型阶段可用几何图形或占位图；占位文件名必须带 `_placeholder`，替换后删除引用与文件。
### Godot 导入与引用
- 导入设置属于资源的一部分。调整压缩、过滤、重复、mipmap 或音频循环后，提交对应 `.import` 变化。
- 像素风资源关闭过滤；普通 2D 美术按项目视觉目标统一过滤和压缩策略，不让单个资源随意例外。
- 场景与脚本通过 `preload()`、`load()` 或 Inspector 引用稳定资源路径；不得在运行时按目录扫描选择正式资源。
- 不移动已被引用的资源；若必须移动，使用 Godot 编辑器的移动/重命名能力，并运行项目检查引用。
- 避免直接编辑 `.import` 的内部格式；优先在 Godot Import 面板修改设置。
### 场景与可复用资源
- 一个场景代表可独立实例化的对象或界面，例如球员演员、足球、比赛场地、比分面板。
- 场景根节点名称表达角色，不使用 `Node2D`、`Control2` 等默认名称。
- 场景实例通过导出资源、主题或数据资源配置差异，不复制整份场景制造球员或球队变体。
- 可复用视觉参数进入 `Theme`、`StyleBox`、`ShaderMaterial` 或专用 `.tres`，避免散落在多个场景的 Inspector 属性中。
- 动画资源、粒子资源与材质命名须与所属对象一致，例如 `ball_trail_material.tres`、`player_knockdown_animation.tres`。
### 音频
- 运行时音频可使用 OGG 或 MP3；保留无损原始音频在 `assets/source/`。
- 音效使用单声道，音乐可使用立体声；避免将不必要的长音频载入内存。
- 循环音乐文件使用 `_loop` 后缀，并在导入设置中确认无爆音循环。
- 声音的播放时机由表现层根据 `MatchEvent` 决定；核心模拟不得直接播放音效。
- 每个重要音效至少保留两种可替换变体，随机选择由表现层控制且不影响比赛结果。
### 数据资源
- 所有球员的静态定义集中维护在 `resources/data/players.csv`。CSV 是球员属性与词条的唯一编辑入口，不再为每名球员创建 `.tres` 文件。
- 运行时由 `PlayerDataRepository` 读取 CSV，并转换为强类型 `PlayerDefinition`；之后比赛逻辑只读取 `PlayerDefinition`，不直接解析 CSV。
- 表格一行对应一名球员。`player_id` 是不可变、唯一的 ASCII 标识；`display_name` 仅供显示，可使用中文。
- 最小列集：`player_id`、`display_name`、`default_role`、`speed`、`shooting`、`strength`、`skill`、`stamina`、`tackling`、`goalkeeping`、`trait_ids`、`visual_id`。
- `trait_ids` 使用稳定词条 ID，并以英文半角竖线 `|` 分隔，例如 `aggressive|power_shooter|risk_passer`；不在同一单元格记录中文说明或规则数值。
- 空单元格只允许用于明确的可选字段；7 项属性、`player_id` 和 `display_name` 不得为空。属性范围、词条数（3–5 个）与重复 ID 由导入校验器检查。
- CSV 使用 UTF-8 编码、逗号分隔、第一行固定为表头。包含逗号、引号或换行的显示文本必须遵循 CSV 转义规则；优先避免在显示名中使用这些字符。
- 比赛实时数据不写回 CSV，包括当前位置、速度、剩余体力、倒地、球权、临时状态及本场统计；这些数据属于 `PlayerMatchState`。
- 所有可表格化的静态数据以 CSV 统一维护：`players.csv`、`teams.csv`、`team_players.csv`、`traits.csv`、`states.csv`、`match_configs.csv`。表之间只使用稳定 ID 关联，不复制名称或属性。
- `teams.csv` 仅定义球队身份、显示信息和默认阵型；`team_players.csv` 用 `team_id`、`player_id`、`slot`、`default_position` 表示阵容归属与顺位，避免在团队表中塞入重复球员列。
- `traits.csv` 与 `states.csv` 定义稳定 ID、显示信息、行为修正参数和可选分类；`match_configs.csv` 保存可选比赛预设及其基础参数。复杂、非表格化的规则计算仍由 GDScript 实现。
- 运行时由统一的 `DataRepository` 按加载顺序读取并校验所有表，再构建强类型定义对象。校验包含表头、字段类型、ID 唯一性、跨表引用、数值范围与循环关系。
- `.tres` 仅用于 Godot 原生或表现层资源，例如 `Theme`、`StyleBox`、`ShaderMaterial`、动画、粒子和复杂场景配置；它们不可成为球员、球队或规则数值的权威来源。
- 规则数据改动应可审查：避免二进制或不可读格式；原型数值集中在 `resources/data/`，不要分散在 UI、场景或特效资源中。
### 临时资源与许可证
- 临时资源统一放入 `assets/_scratch/`，不得被正式场景或发布构建引用；每周或阶段结束前清理。
- 外部资源必须在同目录或 `docs/third_party_assets.md` 记录来源、许可证、作者署名要求和修改情况。
- 未确认商业使用权的外部资源只能用于本地探索，不能进入可发布版本。
- 生成式素材同样记录生成来源、提示词版本或许可信息，以及是否经过人工修改。
### 提交前检查
- 新资源位于正确目录，文件名符合 `snake_case`，不存在默认或临时名称。
- 移动或重命名资源后，项目无丢失引用，相关场景能正常加载。
- 运行资源具备可追溯的源文件或外部来源记录。
- 规则数据、视觉表现与音频播放职责未混在同一资源或脚本中。
- 不提交无引用的占位资源、重复导出物、缓存文件或来源不明素材。

## 模块开发前置条件

- 开始开发某个模块前，先检查 Notion「幸运足球」页面下是否有该模块对应的文档；若没有，不要直接开始开发，先提醒用户撰写文档，待文档就绪后再继续。

## 测试执行约束

- 默认不进行截图、录屏、离屏渲染或其他与画面渲染相关的测试；只有用户明确指定需要时才执行。
