# Guideline 2.1 · 审核补充材料

准备日期：2026-11-25。目标：ID Photo Maker / AutoIDPhoto，Mobile Soft，shenok.smth@gmail.com。

## 最新：已提供真机录屏链接

新版 `reply-and-notes-en-GB-with-video-links-DRAFT.txt` 已加入用户提供的 iPhone/iPad YouTube Shorts 地址，3222 字符，可在填完真实设备型号、系统版本及 version/build 后用于版本页 App Review Notes。第6项提供官方许可引用，不声称本地授权材料核验已完成。两个视频在当前工具中未能播放验证，请在未登录浏览器中检查可观看性、视频开头启动过程及对应实际构建和最新正式版系统。提交前也需核对本地模型授权依据。此新版检查结果见 `video-links-validation.json`；旧草稿及旧验证记录保留作为历史。

## 当前交付

- `notes-en-GB-DRAFT.txt`：按 Apple 六项要求编写的英文审核备注草稿，3605 字符。所有方括号占位必须填完并再次检查 4000 字节限制，不能原样提交。
- `attachments/demo-portrait.png`：已确认可公开使用的 AI 虚构成人演示素材，复制自项目 `design/demo/cartoon-portrait.png`。在 App Review 附件中提供，或另行放到审核员无需登录即可下载的地址，然后在备注中注明实际文件名或链接。该附件没有自动上传。
- `validation.json`：草稿长度和未完成项目。没有声称实机测试或视频已完成。

## 1. 实机录屏

Apple 此次明确要求最新操作系统的物理设备录像。请用支持当前正式版系统的真机，安装对应待审核构建（优先从 TestFlight 安装同一构建），记录实际型号、系统版本和 App version/build。此前模拟器截图不能替代这个视频。App 同时支持 iPhone/iPad，实机 QA 应覆盖两个设备平台；备注只填写实际完成的测试。

建议录制约 2–3 分钟，保持连续易懂，不拼接截图或伪造界面：

1. 先开始系统录屏，在主屏幕点击 App 图标，清楚显示启动过程。
2. 展示规格页（中文系统默认中文，其他系统默认英文；已手动选择则沿用偏好），确认尺寸、头部占幅、纸张、分辨率和照片背景，再点击 Confirm。
3. 展示相机预览/拍摄流程；拍摄素材须得到当事人同意，避免暴露其他人的照片或私人信息。
4. 通过文件夹选择演示样图，展示自动头框，手动移动或缩放至绿色。
5. 点击 Generate Photo & Print Sheet，等待真实处理完成，展示单张照片和八张拼版。
6. 更换蓝色或红色背景并重新生成，证明换背景功能实际运行。
7. 通过分享菜单保存到照片并展示结果，再展示 JPEG/PDF 分享。允许需要的系统权限。
8. 简单展示中英文切换，然后结束录屏。

录屏失败、空图、崩溃或抠图失败时先修复并用新构建重测，不要在备注中声称成功。Apple 的本条要求是实机系统录屏；本 App 不依赖独立外设，因此没有额外“配对外设”演示流程。

视频可作为审核附件提供，或提供稳定、无需登录或申请权限的直接观看/下载链接。以实际 Connect 支持的附件类型和大小为准；不要把审核演示填进商店的 App Preview 栏来替代 Notes 中的视频材料。不要公开包含私人照片或账号信息的视频。

## 2–5. 功能、访问、外部工具、地区差异

草稿依据当前本地源码，不保证与已经提交的二进制完全一致，提交前请核对：

- 面向普通个人用户的证件照裁切、背景处理与打印排版工具，不是单一组织内部 App。
- 没有注册/登录/账号、社区或用户间发布平台、应用内购买、订阅或付费功能解锁。无需演示账号，不必为本封模板要求新增账号删除或社区举报/拉黑功能。App Store 下载价格未从后台核查，不要把它描述为“免费”除非实际一致。
- Apple AVFoundation / Photos / PhotosUI / Vision / Core ML / Core Graphics / ImageIO，及随包的 MODNet 模型。在本机处理，不把照片送到云端 AI。系统分享接收方由用户选择。
- 当前代码没有按地区分支的功能或内容；仍需核对实际提交版本和分发配置。语言选择与地区功能限制不是同一回事。

## 6. MODNet 授权依据

官方目前的 README 声明代码和模型采用 Apache-2.0；本机 Python 旧副本 README 仍写 CC BY-NC-SA 4.0。必须核对打包权重对应的来源及适用许可，保留官方许可/版权声明并说明转换为 Core ML 的改动。不能仅用“开源”二字代替授权依据，也不能在核查未完成时写“已获得作者单独授权”。

当前模型元数据记录：MODNet webcam portrait matting，来源 `https://github.com/ZHKKKe/MODNet`；checkpoint SHA-256 为 `913b82b66558db39b6286c150f809017d7528c872b156eb14333c9c6cb52108b`。这仅是来源追溯信息，不是授权核验结论。当前本地 App 目录未发现打包的 LICENSE/NOTICE，相关补齐工作未在这次文案任务中执行。

建议提供：对应上游许可副本、仓库版本/来源、模型文件与原始权重关系、Core ML 转换说明，以及适用的 NOTICE。保存为审核附件或提供可访问链接，在 Notes 第6项引用实际材料。

## 提交操作

1. App Store Connect → App → 当前 iOS 版本 → App Review Information → Notes，填入完成后的英文说明。
2. 添加视频/样图/授权材料附件，或将可访问的视频和文档链接写入 Notes。
3. 在 App Review 的当前信息请求下回复，简要指出这六项已补到何处，附上必要文件。
4. 按此次 Apple 消息要求重新提交审核。仅补 metadata/材料且同一构建已通过实机验证时，可以重提同一构建；修改 App 代码或资源时应增加 build number、上传新构建，并录制对应构建。

不是发送一条“已修改”回复就算完成；要确认 Notes、附件和实际待审构建均正确，并完成界面上的重新提交步骤。本次没有向 Apple 发送任何消息或提交审核。

## 官方依据

- https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages/
- https://github.com/ZHKKKe/MODNet#license
