# Nakama 能力边界说明

本文档说明 Breach 项目中哪些能力可以直接使用 Nakama，哪些能力需要在 Godot 客户端或 Go 服务端自行实现。

## 一句话结论

**Nakama 负责在线游戏基础设施，Breach 自己负责具体游戏规则。**

Nakama 可以提供账号、连接、匹配、房间、实时消息、存储、排行榜、聊天、封禁等通用后端能力；但玩家移动、射击、伤害、视野、种包、拆包、回合胜负等玩法逻辑仍然必须由项目自己的 Go authoritative match 实现。

## 可以交给 Nakama 的能力

### 账号与身份

- 匿名登录、设备登录、邮箱登录、第三方平台登录。
- 用户 ID、用户名、Session Token。
- 在线状态、好友、黑名单。

### 实时连接与消息通道

- WebSocket 连接管理。
- 客户端加入、离开 match。
- 客户端通过 `socket.send_match_state_async(...)` 发送实时输入。
- 服务端通过 `dispatcher.BroadcastMessage(...)` 广播权威状态。
- 断线、重连、Session 识别。

### Authoritative Match 框架

Nakama 提供 authoritative match 的生命周期容器：

- `MatchInit`
- `MatchJoinAttempt`
- `MatchJoin`
- `MatchLeave`
- `MatchLoop`
- `MatchTerminate`
- `MatchSignal`

也就是说，房间生命周期、固定 tick loop、消息收发管道可以使用 Nakama；但 `MatchLoop` 里具体怎么移动、开枪、判定伤害、处理炸弹，需要项目自己写。

### 匹配与房间发现

- 自动 matchmaking。
- 创建 match。
- 加入指定 match。
- 使用 match label/filter 查询房间。

后续可以基于这些能力实现 3v3 快速匹配、排位匹配、自定义房间、地图和模式过滤。

### 服务端存储

Nakama Storage 可以存储低频、持久化数据，例如：

- 玩家配置。
- 解锁进度。
- 角色选择。
- 装备方案。
- 统计数据。
- 设置项。

### 排行榜与统计

- 胜场榜。
- 击杀榜。
- 段位分榜。
- 周榜、赛季榜。
- 玩家历史统计。

### 聊天与社交

- 房间聊天。
- 队伍聊天。
- 私聊。
- 好友系统。
- 群组或战队。

### RPC 接口

低频、非实时逻辑适合通过 Nakama RPC 实现，例如：

- 拉取配置。
- 保存 loadout。
- 请求匹配。
- 查询玩家档案。
- 购买或解锁物品。

高频战斗输入不适合走 RPC，应该继续使用 match state 消息。

### 管理、日志与封禁

- Nakama Console 管理后台。
- Runtime logger。
- 用户查询。
- 服务端踢人：`dispatcher.MatchKick(...)`。
- 用户封禁：`nk.UsersBanId(...)`。

## 需要项目自行实现的能力

以下能力属于 Breach 的核心玩法，Nakama 不会直接提供：

- 玩家移动模拟。
- 地图碰撞和障碍判定。
- 子弹、射线、投掷物逻辑。
- 武器射速、弹药、换弹、后坐力。
- 命中、伤害、死亡、击杀判定。
- 圆形视野、锥形视野、遮挡、动态阴影。
- 炸弹种植、拆除、爆炸。
- 回合计时、胜负判定、阵营交换。
- 经济、分数、阵营等级、解锁规则。
- 角色技能和终极技能。
- 僵尸 AI 和中立目标逻辑。
- 客户端预测、插值、服务器校正。
- Protobuf 消息定义和兼容策略。
- Godot 端表现、动画、音效、UI。

## 推荐分层

| 层级 | 负责内容 |
|------|----------|
| Nakama | 账号、连接、match 生命周期、消息通道、匹配、存储、排行榜、聊天、封禁 |
| Go 服务端 | 权威状态、移动校验、战斗判定、炸弹规则、视野判定、回合逻辑、反作弊 |
| Godot 客户端 | 输入、表现、本地预测、插值、UI、音效、动画、镜头 |
| Protobuf | 高频实时消息、状态快照、协议版本兼容 |

## 实现原则

- 高频实时行为走 authoritative match state 消息，不走 RPC。
- 低频管理行为走 RPC 或 Storage。
- 客户端只发送玩家意图，不直接决定命中、死亡、得分、胜负。
- 服务器保存唯一权威状态，并负责验证所有关键操作。
- Nakama 提供基础设施，玩法规则写在 `server/modules/`。

