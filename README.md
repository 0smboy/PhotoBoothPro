# PhotoBooth Pro

一款 macOS 原生相机应用，类似 Photo Booth，但有两点关键差异：

- **非镜像 (WYSIWYG)**：预览和保存的照片都是他人视角，抬右手屏幕里也在右侧。
- **AI Effects**：去除原有本地滤镜，只保留 Normal，加入 4 种由 OpenAI `gpt-image-1` 驱动的艺术风格：
  - 吉卜力 (Ghibli)
  - 动漫 (Anime)
  - 油画 (Oil Painting)
  - 像素风 (Pixel Art)

## 构建与运行

### 1. 前置依赖

- macOS 14+
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

### 2. 生成 Xcode 工程

```bash
cd /Users/oboy/myClaudeProject
xcodegen
open PhotoBoothPro.xcodeproj
```

### 3. 运行

在 Xcode 中按 `Cmd+R`。首次启动：

1. 系统会请求摄像头权限 → 允许。
2. App 会弹出 onboarding，输入你的 OpenAI API key（以 `sk-` 开头）。Key 保存在 macOS Keychain。

## 使用

- 中间红色按钮拍照。
- 右下 **Effects** 打开风格面板，点击某个风格 tile 切换。
- 选中 AI 风格后拍照，画面上会有 shimmer 动画，约 5-15 秒后风格化照片出现在底部胶片栏。
- 照片保存位置：`~/Pictures/PhotoBoothPro/`
- `Cmd+,` 打开设置可更换 API key。

## 架构

```
Sources/PhotoBoothPro/
├── Camera/       AVFoundation 捕捉层（非镜像）
├── Effects/      Normal + 4 种 AI 风格定义
├── AI/           OpenAI 客户端 + Keychain
├── Gallery/      会话照片存储
├── UI/           原子 UI 组件
└── ContentView.swift  主界面
```

## 技术说明

- 非镜像实现：`AVCaptureVideoPreviewLayer.connection.isVideoMirrored = false`
- AI 后端：`POST https://api.openai.com/v1/images/edits` with `model=gpt-image-1`
- 无第三方 Swift 依赖，仅使用系统 framework
