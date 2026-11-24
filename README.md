# AutoID Photo · iOS 证件照拼版

原生 SwiftUI 应用，使用 Apple Vision 在本机检测人脸，并使用 MODNet / Vision 人像分割处理背景，按毫米尺寸裁切并生成多张证件照的打印拼版。应用运行时无需服务器、Python 环境或网络访问；MODNet 模型转换步骤单独需要 Python。

## 使用

应用内界面首次启动默认使用 English，不跟随系统语言自动切换。点击右上角地球按钮（English 界面显示“中文”，中文界面显示“English”）即可即时切换，选择会保存在本机。切换语言不清空照片、不重置规格，已有照片的提示与背景选项也会更新。系统相册、分享面板等系统界面及权限弹窗由 iOS 的语言设置决定。

1. 每次启动先显示规格设置和醒目的简要使用说明，确认当前证件照尺寸、头高、背景和打印参数后，点击“确定”才进入拍摄页并启动相机。拍摄页左上角规格图标可随时重新设置。顶部“实时视频 / 原图”区域默认使用前置摄像头显示实时画面，首次使用需允许相机权限。下方文件夹图标选择相册照片，快门图标拍摄，相机图标恢复实时预览以便重拍；实时预览时可用切换图标选择前后摄像头。拍摄或导入后，在同一区域显示原图和头部方框。确保头部完整、双肩四周有足够留白。
2. 打开“证件照与打印规格”，选择尺寸、头高范围、纸张大小、分辨率模式、照片间距及背景。设置自动保存在本机。
3. 核对原图上的头部方框：上边对齐头顶（非头发顶部），下边对齐下巴，左右围住头部。拖动框内可整体移动，拖动四角可缩放；不再使用三个独立滑块。触摸操作只在照片本身的显示区域内换算，黑色留白不计入坐标。自动定位和手动拖动时按当前规格实时检查：绿色表示裁切范围可用，红色表示空间不足或头部左右会被裁掉，并显示原因；修改规格后也立即重算。此检查只判断取景范围，不代表抠图或证件照审核已通过。方框只用于定位，不会打印到输出照片上。
4. 点击带拼版网格图标的“生成证件照与拼版”按钮，检查单张与整版预览。两种照片各有一个分享按钮，排列在同一行并与各自预览居中对齐。点开分享菜单可选择“保存到照片”或“分享 JPEG”，打印版还可选择“分享 PDF”。单张文件为 `ID-Photo.jpg`，打印版为 `ID-Photo-Print.jpg` / `.pdf`，均按当前规格生成。图标提供 VoiceOver 名称及悬停提示。

首次选择“保存到照片”时请求照片读写权限，系统可提供有限访问和完全访问选择。分享菜单中的“照片访问权限”可申请权限或检查当前授权；已选有限访问时，显示“打开设置”以切换完全访问。有限访问仍可保存，未获授权或受系统限制时同样提供说明与设置入口。无需照片权限也可使用系统选择器导入或分享为文件。

默认参数参考英国护照照片要求，初始值沿用 Python 项目的 `Config/photo.cfg`，可在“规格设置”中通过“载入默认参数”恢复：

| 项目 | 默认值 |
| --- | --- |
| 单张宽 × 高 | 35 × 45 mm |
| 头顶至下巴 | 29–34 mm，目标取中值 31.5 mm |
| 打印纸宽 × 高 | 6 × 4 英寸（152.4 × 101.6 mm） |
| 分辨率 | 默认保留原图裁切像素；关闭后按指定 DPI 输出（初始 300 DPI） |
| 间距 / 背景 | 2 mm / 浅灰 |
| 背景清理方式 | 人像模型（优先 MODNet，未包含模型时使用 Vision） |
| 排版 | 4 列 × 2 行，共 8 张 |

“保留原图分辨率”默认开启，已有设置缺少该字段时也自动开启，并保留其余参数。相机按当前格式支持的最大照片尺寸请求高质量拍摄；实际尺寸由设备返回。相册与相机输入不再限制长边为 3000 像素，按完整像素纠正方向。单张证件照保留头部占幅所决定的裁切区域像素，不为满足固定 DPI 而缩小或放大；JPEG 按实际像素写入横纵 DPI，保持设定的物理尺寸。PDF 直接使用该单张照片排版。打印 JPEG 按原图有效 DPI 生成，但上限为 2000 万像素，达到限制会提示使用 PDF；此限制不降低单张精度。关闭该选项可恢复 150–600 DPI 的固定输出，300 DPI 时默认单张为 413 × 531 px、整版为 1800 × 1200 px。预览下方显示两种 JPEG 的实际像素尺寸。

首页使用说明为四个步骤，每步一句，英文每句（包括编号）不超过 10 个词；确认规格后才启动视频。

原始背景要求完整裁切区域都在原图内；纯白、浅灰、蓝色、红色背景允许裁切超出原图上边缘，并以相同背景色补齐，但左右或底部缺失仍会报错。选定的头部左右边缘必须完整保留，不会缩小脸部来改变占幅。“生成”按钮固定在拍摄页底部，取景范围不符合规格时禁用。拼版保持单张物理尺寸，余白居中分配。“背景”栏仅保留“照片背景”设置项；纯白为 RGB(255,255,255)，浅灰为 RGB(240,240,240)，蓝色为 RGB(67,142,219) / #438EDB，红色为 RGB(255,0,0) / #FF0000（蓝、红参考 [证件照大师换底色工具](https://id-photo.cn/color/) 的纯色色块），同时用于背景替换和原图上方补白。与 Python 版一致，照片之间及外侧余白使用独立的中灰色（127/255），与白色或浅灰照片背景区分，方便识别每张照片的裁切边界；间距足够时添加照片外部裁切标记。预览、JPEG 和 PDF 使用同一配色。若间距设为 0，相邻照片之间不会有灰色间隔。

## 构建与安装到 iPhone

要求 macOS、Xcode 16 或以上、iOS 17 或以上。工程无外部依赖。

1. 打开 `AutoIDPhoto.xcodeproj`。
2. 在 Xcode → Settings → Accounts 登录 Apple ID。
3. 选择 AutoIDPhoto target → Signing & Capabilities，选择自己的 Team，启用 Automatically manage signing；如 Bundle Identifier 被占用，改为自己的唯一标识。
4. 用 USB 连接并信任 iPhone，按 Xcode 提示在手机启用开发者模式。
5. 在运行目标选择该 iPhone，按 ⌘R 安装运行。首次运行根据需要允许相机、照片权限。相册选择使用系统选择器，不需要读取整个相册。

个人开发签名有效期和设备限制由 Apple 账户类型决定；过期后可通过 Xcode 重新安装。本仓库不包含签名证书或已签名 IPA。

命令行检查（不签名，不可直接安装）：

```sh
xcodebuild -project AutoIDPhoto.xcodeproj -scheme AutoIDPhoto \
  -configuration Debug -sdk iphoneos \
  -derivedDataPath /private/tmp/autoid-derived CODE_SIGNING_ALLOWED=NO build
./scripts/test.sh
```

几何测试通过 Swift 编译器在 macOS 上运行，不依赖模拟器，覆盖默认及自定义纸张排版、头高换算、裁切边界、配置持久化、非法输入，以及前景保留、蒙版方向/行间距、软边混合、空蒙版拒绝、旧设置迁移，以及方框平移、四角缩放、越界限制、编辑后打印尺寸及 JPEG 像素尺寸/DPI 元数据。

## 模拟器试运行

在 macOS 普通终端进入本目录执行：

```sh
./scripts/run-simulator.sh
```

脚本优先使用已启动的 iPhone 模拟器，否则启动一个已安装的 iPhone 模拟器，再构建、安装并启动应用。没有可用模拟器时，先在 Xcode 安装 iOS Simulator runtime 并创建模拟器。可将测试照片拖入模拟器添加到相册，再通过应用选择照片。模拟器没有真实相机，预览区会提示使用文件夹图标导入照片；拍摄、前后摄像头切换和实时视频须在手机验证。

### 使用 Python 同源 MODNet

已提供 Core ML 接入代码及转换脚本；当前本地目录已生成 `AutoIDPhoto/MODNet.mlmodel` 并加入工程。重新构建后，背景处理固定使用人像模型，设置页会显示 MODNet，并直接通过 Core ML 推理，背景处理不再调用 Vision。若其他检出目录缺少该文件，请先执行下面的转换步骤，否则模型方式使用 Apple Vision。人脸定位仍使用 Vision。

在有网络访问的 Mac 普通终端运行一次：

```sh
cd /Users/jialishen/Coding/IOS/AutoIDPhoto
./scripts/prepare-modnet.sh
```

脚本在本目录创建隔离的 `.model-tools` Python 3.11 环境，不更改原 Python 项目。安装约定版本的 PyTorch、torchvision、NumPy 和 coremltools，读取原项目的 `modnet_webcam_portrait_matting.ckpt`，生成 `AutoIDPhoto/MODNet.mlmodel`，成功后自动加入 Xcode target。随后停止应用、按 ⌘R 重新构建，并在规格设置中确认背景模型显示 MODNet。可通过 `--checkpoint photographic` 使用已有 photographic 权重；默认 webcam 与原 `segmentor.py` 一致。

可运行 `./scripts/prepare-modnet.sh --verify` 额外比较转换后模型与 PyTorch 的 alpha 输出（需要本机 Core ML 推理服务正常）。转换脚本默认还会验证 TorchScript 与原 PyTorch 网络的输出一致；这个检查不能替代 Core ML 数值对比及真机验收。

模型使用 RGB 输入、`像素 / 127.5 - 1` 归一化、单通道 alpha 输出。当前转换固定为 512 × 512：原图缩放至正方形推理，蒙版映射回原图后合成；与原 Python 按比例、32 的倍数缩放的流程存在差异，极端长宽比的边缘效果须单独核对。模拟器使用 CPU，手机允许系统选择计算设备。模型随应用离线运行，不上传照片。

转换需要读取本机 Python 项目的 MODNet 源码与权重。原项目携带的旧版 README 声明 CC BY-NC-SA 4.0；分发模型时请同时核实所用权重的授权及来源。源码参考 [MODNet](https://github.com/ZHKKKe/MODNet)，转换方式参考 [Apple Core ML Tools](https://apple.github.io/coremltools/docs-guides/source/image-inputs.html)。

本环境已验证权重加载及 TorchScript 一致性，本地后续已生成 Core ML 文件。尚未在当前执行环境完成 Core ML 推理数值对比及真机验收；文件存在和接入代码通过检查不等于 MODNet 推理已验证。

### 模拟器推理错误

模拟器构建会为 Vision 请求的各计算阶段选择其支持的 CPU，以规避不可用的加速设备。背景合成使用 Core Graphics 解码后的 sRGB 像素与 8 位人物蒙版直接混合，不依赖 Core Image / Metal 蒙版渲染。若仍出现 `Could not create inference context` 等底层推理错误，人脸检测步骤会保留原图、明确提示改用手动定位；未检出人脸或检出多人仍正常报错。若背景分割失败，不会把未处理图片当作已抠图结果；可主动在规格中选择“原始背景”继续验证排版。手机构建仍使用系统自动选择的计算设备，分割效果须用真机确认。输出前会检查蒙版格式、前景像素和头部区域置信度；若人物蒙版为空或未覆盖头部，会停止生成并提示，而不会输出纯色拼版。

## 打印与照片要求

优先使用 PDF：页面大小以物理单位写入，单张位置与宽高按毫米换算。JPEG 也写入 DPI。选择与设置一致的纸张，使用 **100% / 实际大小**，关闭适应页面、填满和无边距自动放大；打印服务可能忽略 DPI 或增加放大，必须用尺核对成品 35 × 45 mm。检查发丝、肩部边缘和背景是否干净。

本工具提供证件照裁切、背景处理与打印排版功能。请人工检查人物边缘、背景和成品尺寸；需要保留照片背景时，可选择“原始背景”。

应用会将人物蒙版与所选背景的合成结果用于输出。MODNet 的 iOS 输入尺寸及预处理与 Python 原始流程存在差异，边缘效果须通过实际照片核对。

## 目录与验证状态

- `AutoIDPhoto/`：SwiftUI 界面、状态与处理管线、几何计算。`CameraController.swift` 在串行队列管理相机，使用 `AVCaptureVideoPreviewLayer` 嵌入实时预览，使用 `AVCapturePhotoOutput` 拍摄，并在切后台、打开相册/设置及退出页面时停止会话。`BackgroundCompositor.swift` 负责蒙版检查及像素合成，`HeadSelectionOverlay.swift` 负责照片上的头部方框交互。
- `AutoIDPhoto.xcodeproj/`：共享 scheme 与签名配置入口。
- `Tests/main.swift`、`scripts/test.sh`：几何与配置检查。

先前已在 Xcode 16.4 / iPhoneOS 18.5 SDK 完成不签名构建；最新 1242 项几何、配置、图像处理、方框编辑、JPEG 导出及双语资源检查通过，模拟器及手机目标的 Swift 源码类型检查通过。加入本地 MODNet 模型后，当前执行环境的完整构建被模型编译器的嵌套沙箱限制阻断（`sandbox_apply: Operation not permitted`）；需在普通 Xcode 环境构建。当前执行环境也无法连接 CoreSimulator/CoreDevice 服务，尚未完成真机安装、相机/相册权限交互及端到端视觉验收。

本次嵌入式相机界面修改已用 Xcode 26.3 / iOS 26.2 SDK 检查模拟器和手机目标的 Swift 源码。真机验收时请依次检查：首次相机授权、实时预览、快门拍摄、原位照片和方框拖动/缩放、重拍、前后镜头切换、相册导入/取消、切后台再返回，以及新版网格按钮生成和导出。模拟器可检查相册与静态照片流程，不支持真实相机预览。

## 应用图标

图标使用青绿色背景、白色人像和裁切框，左上角为 MobileSoft Logo，使用 `design/icon-agent/AutoIDPhoto/AppIcon-1024-v2.png` 的最终版本。工程中的 `Assets.xcassets/AppIcon.appiconset/AppIcon.png` 为不含 Alpha 通道的 1024 × 1024 PNG，Debug / Release 均已指定使用 AppIcon。

当前原图位于 `design/icon-agent/AutoIDPhoto/AppIcon-Master-v2.png`，生成提示词及方式记录于同目录 `AppIcon-Prompt-v2.txt`；最终文件也已保存在 `MobileSoft/Projects/AutoIDPhoto/`。旧版设计记录保留在 `design/app-icon-master-v1.png` 和 `design/app-icon-prompt.txt`。`scripts/prepare_app_icon.swift` 只负责尺寸和色彩格式准备，可用于从原图重新生成上架图标。

## 本地化维护

`AppLanguage.swift` 管理默认英文及语言偏好，`en.lproj` / `zh-Hans.lproj` 保存成对界面和权限说明资源。设置中背景枚举的原始值保持不变，以兼容已保存的配置；显示时才翻译。`scripts/test.sh` 会检查新安装语言、偏好切换、资源加载、翻译键覆盖及格式占位符。

截图脚本现在默认记录英文，中文截图可运行 `python3 scripts/capture-simulator-screens.py --language zh-Hans`；拍摄前按提示在 App 中切到对应语言，该选项不会伪造或替换截图文字。

## 支持页与隐私政策

默认 UK English 的支持页和隐私页位于 `docs/index.html` 和 `docs/privacy.html`，简体中文版通过独立语言链接打开，发布说明及隐私依据见 [Pages 交付说明](release/pages/README.md)。GitHub 仓库为 [doskey75506/AutoIDPhotos_ios](https://github.com/doskey75506/AutoIDPhotos_ios)。网页已填入开发者 Mobile Soft 与支持邮箱 shenok.smth@gmail.com；Pages 尚未验证部署，不能当作已上线的 Connect 链接。

page agent 的已确认默认值为 **Mobile Soft** / **shenok.smth@gmail.com**，本项目后续无需再询问。共享 agent 的默认值合并脚本及配置副本见 [agent-config/page](agent-config/page/README.md)；共享目录受写入限制，需按该说明在本机终端安装一次。

GitHub Pages 使用 `main` 分支的 `/docs` 目录发布，默认页面为 UK English，简体中文通过独立页面切换。
