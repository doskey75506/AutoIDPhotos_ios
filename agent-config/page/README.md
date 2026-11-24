# page agent 默认信息

用户于 2026-11-24 确认以下默认值，后续无需重复询问：

- 开发者名称：**Mobile Soft**
- 支持邮箱：**shenok.smth@gmail.com**

除非用户为具体项目明确指定其他信息，支持页与隐私政策直接使用上述默认值。

`page.toml` 与 `page` 是已补齐默认信息的可审阅配置副本。共享 iOS 配置位于本会话可写范围之外，直接写入被系统拒绝；它尚未自动更新。在普通本机终端运行以下命令，将默认信息合并到现有配置中（保留其他任务说明），同时更新存在的自然语言入口和安装源模板：

```sh
python3 /Users/jialishen/Coding/IOS/AutoIDPhoto/agent-config/page/install-defaults.py
```

可先加 `--dry-run` 检查目标，或用 `--workspace` 指定 iOS 工作区路径。安装脚本只改默认信息专节，不修改其他 agent，也不创建远端仓库。
