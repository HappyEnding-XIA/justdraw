# KidCanvas 交付验收清单

> 目标：交付前不只确认“能编译”，还要确认核心绘画链路在 iPhone 和 iPad 上可启动、可操作、可保存。本文是 T057 起的统一交付口径，后续功能任务完成后必须同步更新对应模块文档或本清单。

## 1. 验收范围

本轮交付面向 KidCanvas 主编辑器，覆盖以下核心流程：

| 编号 | 流程 | 交付标准 | 自动验证 | 人工触控 |
|---|---|---|---|---|
| F01 | 启动 | iPhone/iPad 模拟器可安装、启动、截图非空、不崩溃 | `runtime_smoke_test.sh` | 检查首屏控件无遮挡 |
| F02 | 画笔 | 铅笔、钢笔、蜡笔可切换；宽度预览和笔触可用 | `validate_project.py` + `swift test` | 手绘连续线条 |
| F03 | 橡皮 | 橡皮可切换 circle/cloud/star；尺寸预览和擦除可用 | `validate_project.py` + `swift test` | 擦除已有笔触 |
| F04 | 填色 | 填色工具存在并通过 Swift flood fill 执行 | `validate_project.py` + `swift test` | 点按封闭区域填色 |
| F05 | 取色 | 取色器通过 Swift 采样返回颜色，并更新当前颜色 | `validate_project.py` + `swift test` | 从画布取色后继续绘制 |
| F06 | 印章 | 左侧显示“印章”；可添加、捏合缩放、前移、删除 | `validate_project.py` + `swift test` | 添加印章并捏合缩放 |
| F07 | 颜色面板 | 24/36 色盘、最近色、当前色高亮可用 | `validate_project.py` + `swift test` | 切换色盘并选择颜色 |
| F08 | 自定义色 | Custom 仅保留单一入口；弹出系统取色器 | `validate_project.py` | 选择自定义颜色 |
| F09 | 保存 | 空画布不可保存；有内容后保存到历史和相册 | `validate_project.py` | 画一笔后保存并观察 Toast |
| F10 | 历史 | 草稿、历史缩略图、打开、删除、翻页状态可用 | `validate_project.py` + `swift test` | 保存后打开/删除历史 |
| F11 | 相册导入 | 可从相册导入图片，并重置为干净画布会话 | `validate_project.py` | 选择一张照片导入 |
| F12 | 线稿 | 线稿入口、弹窗、模板加载可用 | `validate_project.py` + `swift test` | 打开线稿并进入绘制 |

## 2. 必跑命令

```bash
find /Volumes/xiaoda_SSD/KidCanvas/justdraw \
  -path '*/.git' -prune -o \
  -path '*/.build' -prune -o \
  -path '*/ai-docs' -prune -o \
  -name '._*' -type f -delete

python3 scripts/validate_project.py

cd Packages/KidCanvasModules
swift test

cd /Volumes/xiaoda_SSD/KidCanvas/justdraw
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' build -quiet

scripts/runtime_smoke_test.sh "iPhone 17 Pro"
scripts/runtime_smoke_test.sh "iPad Pro 11 M4"
git diff --check
```

## 3. 自动验证边界

`scripts/validate_project.py` 已覆盖：

- iPhone + iPad 工程配置、横屏配置、Info.plist 和资源接入。
- OC 业务源码清零、Bridging Header 移除、Swift-first 架构事实。
- 多语言资源，默认中文、支持英文，且用户可见“贴纸”产品语义改为“印章 / Stamp”。
- 左侧工具栏、底部画笔 Dock、右侧颜色/印章/橡皮面板的关键 UI 结构。
- 画笔、橡皮、填色、取色、撤销/重做、保存、草稿、历史、相册导入、线稿、印章缩放约束的关键路径。
- SPM 单 package 多 target 的依赖方向和模块文档完整性。

`swift test` 已覆盖：

- `KCCommon` 基础类型与颜色解析。
- `KCDomain` 内容布局、最近色、印章分类、印章缩放约束、历史分页、面板折叠状态。
- `KCDrawingEngine` flood fill、取色、线稿绘制、蜡笔纹理和笔触数学。
- `KCContentCatalog` 内置内容加载。
- `KCSessionPersistence` 会话保存、草稿和历史存储。

`runtime_smoke_test.sh` 已覆盖：

- 指定模拟器启动。
- Debug 构建、安装、启动。
- 进程存活检查。
- 首屏截图生成与非空检查。

## 4. 人工验收建议

自动化不能完全替代手指/鼠标交互，交付前建议按以下顺序快速点一遍：

1. iPhone 横屏：确认左侧工具栏可滚动，底部 Dock 不遮挡系统安全区，右侧面板不溢出。
2. iPad 横屏：确认默认横屏体验正常，主工具、颜色、历史、印章区域无遮挡。
3. 画笔：分别用铅笔、钢笔、蜡笔画线，调节尺寸后继续绘制。
4. 橡皮：切换三种形状并擦除已有内容。
5. 颜色：切换 24/36 色盘，选择颜色，打开 Custom 取自定义色。
6. 填色/取色：填色后用取色器取回颜色，再继续画线。
7. 印章：添加印章，捏合放大/缩小，点击前移和删除。
8. 保存/历史：空画布保存应失败；有内容保存应出现 Toast，并在历史中可打开/删除。
9. 相册/线稿：导入照片、加载线稿后确认画布可继续绘制。

## 5. 交付记录模板

每次阶段交付时，在看板或发布说明中记录：

```text
交付验收：
- validate_project.py：通过 / 失败
- swift test：通过 / 失败，测试数量
- iPhone build：通过 / 失败
- iPad build：通过 / 失败
- iPhone runtime smoke：通过 / 失败，截图路径
- iPad runtime smoke：通过 / 失败，截图路径
- 人工触控：已完成 / 未完成，未覆盖项说明
- 文档同步：列出更新的 docs 路径
```
