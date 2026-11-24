# iOS icon agent

定义：`icon.toml`。继承父会话模型和权限，仅负责当前 iOS App 的图标。

固定规则：左上角嵌入 MobileSoft 原 Logo，宽度 20%–25%（默认 22%），等比缩放；最终 PNG 放到 `/Users/jialishen/Work/MobileSoft/Projects/<项目目录>/`。默认版本化保存，不替换现有图标。

安装到 iOS 工作区和个人 agent 注册目录：

```sh
python3 /Users/jialishen/Coding/IOS/AutoIDPhoto/agent-config/icon/install.py
```

安装器写入 `/Users/jialishen/Coding/IOS/.codex/agents/icon.toml`，在 `release-agents/icon.toml` 保留副本，创建工作区入口 `/Users/jialishen/Coding/IOS/icon`，并将个人 `~/.codex/agents/icon.toml` 链接到工作区定义，以便独立应用工作区发现角色。不会改模型、权限、其他 agent 或 App。

安装后新建会话，在目标应用目录中输入：

> 调用 icon agent，根据当前 app 内容生成图标。

也可输入 `../icon干活`；这是自然语言任务入口，不是终端命令。若客户端不能加载角色，读取入口定义执行并明确说明 fallback。

配置格式依据：https://learn.chatgpt.com/docs/agent-configuration/subagents
