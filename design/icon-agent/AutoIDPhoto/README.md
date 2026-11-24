# AutoIDPhoto 图标产物

最终图标：`AppIcon-1024-v2.png`。使用内置 image_gen，以 MobileSoft 原 Logo 及已有图标作为参考生成，并进行一次 Logo 定向修正。青绿色背景、人像和裁切框表达通用证件照制作功能，没有国旗、护照等场景元素。

已验证：1024 × 1024 PNG、无 Alpha、RGB、sRGB IEC61966-2.1；已查看完整图和 128 像素缩略图。左上角 Logo 白底区域约 x=72、y=70、宽=250、高=252 像素（基于白色像素阈值的近似测量），宽占 24.41%，在 20%–25% 范围内。原 Logo 作为编辑参考并做视觉核对，没有声明逐像素粘贴。

原始生成图：`AppIcon-Master-v2.png`；缩略图：`AppIcon-Preview-128-v2.png`；完整提示词及验证记录：`AppIcon-Prompt-v2.txt`。v1 文件仅为设计过程中的候选稿。

外部目标为 `/Users/jialishen/Work/MobileSoft/Projects/AutoIDPhoto/`。当前沙箱创建该目录时返回 `Operation not permitted`，因此尚未保存到外部目录。在普通 Mac 终端执行：

```sh
python3 /Users/jialishen/Coding/IOS/AutoIDPhoto/design/icon-agent/AutoIDPhoto/copy-to-projects.py
```

脚本只复制四个最终文件，不覆盖内容不同的已有同名文件。不修改 App 的现有 AppIcon 或工程设置。
