# KidCanvas

KidCanvas 是一个面向儿童的 iPhone / iPad 绘画应用项目。当前仓库包含已有原型、产品文档、架构设计文档，以及后续向 `Swift-first + SPM 模块化` 演进的方案。

English version: [README.en.md](README.en.md)

## 当前状态

- 当前工程仍保留可参考的原型实现。
- 架构方向已经明确为：`Swift-first`、`SPM modularization`、`UIKit/Core Graphics canvas core`、`SwiftUI panels where appropriate`。
- 正式文档已归档到 `docs/`。
- AI 协作材料位于 `ai-docs/`，默认不进入版本库。

## 文档导航

- 产品需求 / Product requirements:
  [docs/product/prd.md](docs/product/prd.md)
- 技术架构 / Technical architecture:
  [docs/architecture/TECHNICAL_ARCHITECTURE.md](docs/architecture/TECHNICAL_ARCHITECTURE.md)
- 模块化架构 / Modular architecture:
  [docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md](docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md)
- 代码规范 / Coding standards:
  [docs/architecture/CODING_STANDARDS.md](docs/architecture/CODING_STANDARDS.md)
- 模块解耦 / Module decoupling:
  [docs/architecture/MODULE_DECOUPLING_GUIDELINES.md](docs/architecture/MODULE_DECOUPLING_GUIDELINES.md)
- 版本记录 / Release notes:
  [docs/release/CHANGELOG.md](docs/release/CHANGELOG.md)
- AI 协作区 / AI collaboration workspace:
  `ai-docs/`

## 快速开始

1. 在 macOS 上用 Xcode 打开 `KidCanvas.xcodeproj`。
2. 选择一个 iPhone 或 iPad 模拟器运行 `KidCanvas` scheme。
3. 如果需要命令行构建，先确认本机可用的 simulator 名称，再执行：

```bash
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=KidCanvas iPad Pro 11 M4' build
```

## 本地校验

如需运行当前仓库附带的轻量校验脚本，请使用：

```bash
python3 scripts/validate_project.py
```

该脚本主要校验：

- plist / json 可解析
- Xcode 工程引用完整
- iPhone / iPad 横屏配置正确
- 原型能力覆盖到绘制、填色、贴纸、历史、导入导出等核心范围

## 仓库说明

- `KidCanvas/`：当前应用工程源码
- `docs/`：正式文档
- `ai-docs/`：本地 AI 协作文档
- `scripts/`：辅助脚本

## 维护原则

- 中文优先，必要处支持英文术语。
- 正式设计和规范优先写入 `docs/`。
- 新增架构与代码应遵循模块化、分层、解耦原则。
