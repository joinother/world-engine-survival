# CLI 与 AI 接口草案

CLI 是游戏的一个受控客户端，不直接修改内存。所有请求都经过同一套规则验证器，因此人类玩家、AI 玩家和管理员可以共用世界接口。

## 三种权限

### player

只能执行正常玩家动作：移动、搜刮、使用、建造、交谈、驾驶和休息。

### director

可以推进时间、生成事件、创建任务和观察状态，但不能随意增加玩家库存或绕过规则。

### admin

可以维护服务器和开发存档：生成实体、修复地图、恢复快照和导入 Mod。所有操作写入审计日志，并支持回滚。

## 命令示例

```text
world.state
player.move north
player.search building_102
build.place barricade at=12,8
agent.follow survivor_03 target=safehouse_1
time.advance minutes=60
event.start blackout duration=3d
world.snapshot name=before_outbreak
world.rollback name=before_outbreak
```

当前 Demo 使用空格分隔的本地命令作为过渡层：

```text
state
needs
content list
time advance 60
event start horde
world snapshot before_outbreak
world rollback before_outbreak
world snapshots
audit tail
```

权限会在命令执行前检查：`player` 只能观察和执行生存动作，`director` 可以推进时间和启动事件，`admin` 才能生成实体、创建快照、回滚世界和切换角色。每条命令都会保留操作者、命令、结果和世界时间。

## 安全规则

- 命令使用 JSON-RPC 或本地 Unix socket 传输；
- 每个命令带有操作者、权限、时间和世界版本号；
- 管理员命令默认只能作用于开发存档或沙盒服务器；
- 所有写操作可追踪、可回滚、可限速；
- AI 玩家只能看到授权范围内的观察结果；
- 多人服务器禁止把管理员命令暴露给普通 AI。

## AI 玩家接口

AI 玩家收到观察结果后，只能发出合法动作：

```json
{
  "observe": ["player_position", "nearby_items", "visible_threats"],
  "action": {"type": "search", "target": "building_102"}
}
```

AI 管理员则可以使用更高层的事件和内容命令，但必须遵守服务器权限和回滚机制。
