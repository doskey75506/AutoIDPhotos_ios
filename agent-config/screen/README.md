# iOS screen agent

`screen.toml` 定义模拟器运行及真实界面截图流程；与 icon agent 使用相同的项目资料目录：

`/Users/jialishen/Work/MobileSoft/Projects/<项目目录>/`

截图直接保存到该目录，按页面、设备、语言和版本命名，不覆盖 icon 或旧截图。附带截图清单，说明实际构建、模拟器、尺寸及待验证事项。默认只运行和截图，不提交代码或上传商店。

安装一次：

```sh
python3 /Users/jialishen/Coding/IOS/AutoIDPhoto/agent-config/screen/install.py
```

安装器写入工作区 `.codex/agents/screen.toml`、`release-agents/screen.toml` 和 `screen` 入口，并在个人 `~/.codex/agents/screen.toml` 建立链接。已有不同内容的文件会保留并报错；不修改其他 agent 或权限。

安装后新建会话，在目标 App 目录调用：

> 调用 screen agent，运行模拟器并生成截图。

也可使用自然语言入口 `../screen干活`，这不是终端命令。客户端未加载自定义角色时，读取定义执行并明确说明 fallback。

配置格式：https://learn.chatgpt.com/docs/agent-configuration/subagents
