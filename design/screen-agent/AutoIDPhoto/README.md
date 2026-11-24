# AutoIDPhoto 模拟器截图

本次执行未取得真实截图。没有 PNG 图片，不应将本目录记录当成截图成功。

## 实际阻碍

- 当前 Xcode：26.3（17C529）。
- `xcrun simctl list devices available -j` 无法连接 CoreSimulatorService，包含 `Operation not permitted` 和 `Connection refused`。
- 原生计算机控制先遇到同一 bundle ID 对应两套 Xcode；指定当前 `/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app` 后仍返回 `timeoutReached`。
- 本次未构建、安装、启动 App，未完成任何页面视觉验收，也未验证 App Store 截图规格。

## 在 Mac 普通终端运行

```sh
python3 /Users/jialishen/Coding/IOS/AutoIDPhoto/scripts/capture-simulator-screens.py
```

脚本默认将真实截图直接存到 `/Users/jialishen/Work/MobileSoft/Projects/AutoIDPhoto/`，与图标处于同一目录层级。若该目录不可写，才回退到当前工作区本目录。

它会选择唯一已启动的可用 iPhone（或启动一个可用 iPhone）、记录并始终使用明确 UDID、构建本次源码、安装和启动 App。启动后在指定模拟器手动切换页面，回车截屏；输入 `s` 跳过，`q` 结束。默认只拍无需照片的首页和参数设置页。

多个 iPhone 已启动时，先用 `xcrun simctl list devices available` 查询，再增加 `--device <UDID>`。如另有明确可公开使用的测试照片，可增加 `--include-photo-pages` 拍摄编辑和真实生成结果页；默认不会读取或导入个人照片。

截图为原生 PNG，按页面、设备、语言和递增版本命名。Manifest 记录构建命令、App 版本、模拟器、文件尺寸、结果和待验证项。不会覆盖旧图、icon，不清空模拟器，不上传商店，也不额外叠加角标或生成假界面。

脚本已通过 `--help` 和 Python 语法检查；本环境实际运行只完成 Xcode 版本读取，随后因 CoreSimulator 连接失败而停止。`Screenshots-Manifest-v1.json` 和 `Screenshots-Diagnostic-v1.txt` 记录这次阻碍。
