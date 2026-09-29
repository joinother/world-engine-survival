# CLI 与 AI 接口草案

CLI 是游戏的受控客户端。人类玩家、AI 玩家和管理员共用同一套动作验证器，区别只在权限和可见状态范围。

## 三种权限

### player

只能执行正常生存动作：观察、移动、攻击、搜刮、使用食物/水/绷带和交互。

### director

可以推进时间、启动感染者潮并观察完整的开发场景，但不能直接修改库存或绕过规则。

### admin

可以生成测试物件、创建快照、回滚存档和切换角色。每条写操作都会进入审计日志。

## 当前本地命令

```text
state
needs
content list
use food
use water
use bandage
time advance 60
event start horde
world snapshot before_outbreak
world rollback before_outbreak
world snapshots
audit tail
```

命令行只监听 `127.0.0.1:9555`。它适合本地 AI 沙盒和开发工具，不能直接暴露到公网。

## JSON-RPC

运行游戏后，Godot 提供换行分隔的 JSON-RPC 2.0 接口：

```json
{"jsonrpc":"2.0","id":1,"method":"player.observe","params":{"role":"player","radius":12}}
```

当前方法包括：

- `world.state`
- `player.observe`
- `player.move`
- `player.interact`
- `player.attack`
- `world.content`
- `world.command`
- `time.advance`
- `event.start`
- `world.snapshot`
- `world.rollback`
- `world.snapshots`

仓库里的 Python 客户端只依赖标准库：

```bash
python3 cli/world_engine_cli.py observe
python3 cli/world_engine_cli.py --role director advance 60
python3 cli/world_engine_cli.py --role admin snapshot before_outbreak
```

## AI 玩家与 AI 管理员

AI 玩家接收授权范围内的状态，例如位置、附近搜刮点、需求和威胁，然后发出移动、攻击或交互动作。AI 管理员可以启动事件、生成测试对象或恢复快照，但仍必须通过权限、审计和回滚机制。

```json
{
  "observe": ["player_position", "nearby_items", "nearby_threats"],
  "action": {"type": "interact", "target": "debris:2"}
}
```

多人服务器阶段还需要身份认证、速率限制、命令签名和更细的地图可见性，不能把开发端口当作公网管理接口。
