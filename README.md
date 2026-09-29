# 世界引擎 / World Engine

一个开源、可 Mod 的现代 3D 生存模拟器原型。

第一阶段目标是做一款固定俯视视角的单人生存原型：移动、搜刮、需求、战斗、安全屋、CLI 管理台和 AI 玩家接口先形成一个可玩的闭环。Cataclysm-DDA 作为数据驱动和 Mod 架构的研究参考；项目不复制其代码、数据、素材或文本。

## 开发

- 引擎：Godot 4.x
- 运行：打开本目录并运行 `project.godot`
- CLI / AI：通过同一套受控命令接口读取或改变世界
- 外部接口：本地 JSON-RPC 服务监听 `127.0.0.1:9555`，附带 Python CLI 客户端
- Mod：`mods/<id>/manifest.json` + `content.json`，支持 `extends` 继承和覆盖
- 存档：管理员可以创建 JSON 快照并回滚开发世界
- 开源策略：代码、游戏数据、第三方代码和第三方素材分开记录许可证

文档：

- [项目路线](PROJECT_PLAN.md)
- [CLI 与 AI 接口](CLI_SPEC.md)
- [开源引用矩阵](REFERENCE_MATRIX.md)
- [第三方声明](THIRD_PARTY_NOTICES.md)
- [Godot MCP 配置示例](.mcp.json.example)
- [开源生态推进路线](OPEN_SOURCE_ROADMAP.md)
- [开源资产管线](ASSET_PIPELINE.md)
