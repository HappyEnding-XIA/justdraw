# KidCanvas 交付验收清单

> 目标：交付前不只确认“能编译”，还要确认核心绘画链路在 iPhone 和 iPad 上可启动、可操作、可保存。本文是 T057 起的统一交付口径，后续功能任务完成后必须同步更新对应模块文档或本清单。

## 1. 验收范围

本轮交付面向 KidCanvas 主编辑器，覆盖以下核心流程：

| 编号 | 流程 | 交付标准 | 自动验证 | 人工触控 |
|---|---|---|---|---|
| F01 | 启动 | iPhone/iPad 模拟器可安装、启动、截图非空，并生成横屏观察图、不崩溃；首帧前不得同步读取历史 metadata / 草稿缩略图，颜色、草稿、历史、印章加载必须错峰 | `runtime_smoke_test.sh` + `validate_project.py` | 检查首屏控件无遮挡，启动后 1 秒内无明显长卡顿 |
| F02 | 画笔 | 铅笔、钢笔、蜡笔可切换；宽度预览和笔触可用；蜡笔不能只表现为半透明粗线，必须有断续蜡痕、粗颗粒和纸纹留白 | `validate_project.py` + `swift test` + `drawing-tools` | 手绘连续线条，比较铅笔/钢笔/蜡笔同色同宽差异 |
| F03 | 橡皮 | 橡皮可切换 circle/cloud/star；尺寸预览和擦除可用 | `validate_project.py` + `swift test` + `drawing-tools` | 擦除已有笔触 |
| F04 | 填色 | 填色工具存在并通过 Swift flood fill 执行 | `validate_project.py` + `swift test` + `drawing-tools` | 点按封闭区域填色 |
| F05 | 取色 | 取色器通过 Swift 采样返回颜色，并更新当前颜色 | `validate_project.py` + `swift test` + `drawing-tools` | 从画布取色后继续绘制 |
| F06 | 印章 | 左侧显示“印章”；可添加、选中反馈清楚、拖动、捏合缩放、旋转、前移、删除、撤销/重做 | `validate_project.py` + `swift test` | 添加印章后依次点验选中、拖动、捏合、旋转、前移、删除、撤销/重做 |
| F07 | 颜色面板 | 24/36 色盘、最近色、当前色高亮可用 | `validate_project.py` + `swift test` + `drawing-tools` | 切换色盘并选择颜色 |
| F08 | 自定义色 | Custom 仅保留单一入口；弹出系统取色器 | `validate_project.py` + `system-ui` | 选择自定义颜色 |
| F09 | 保存 | 空画布不可保存；空画布保存反馈必须提示“先画再保存”；有内容后优先保存到 App 内历史；系统相册作为附加导出，失败时必须显示独立文案且不能否定本地保存成功 | `validate_project.py` + `empty-save` + `save-history-restore` + `photo-export-failure` | 空画布点保存应显示“先画再保存”；画一笔后保存应显示“已保存”并进入历史；相册导出失败时应显示“已保存，相册未保存” |
| F10 | 历史 | 草稿、历史缩略图、打开、删除、翻页状态可用；删除按钮文案必须跟随实际删除目标显示“删除选中 / 删除当前 / 删除草稿 / 删除最近”；删除已保存作品不得在主线程写 metadata 或删图片文件；选中/按下已保存缩略图不得露出默认 photo 占位 | `validate_project.py` + `swift test` + `save-history-restore` | 保存后打开/删除历史；选中非最近缩略图后确认删除按钮不再显示“删除最近”；连续点按历史缩略图检查无占位闪现 |
| F11 | 相册导入 | 可从相册导入图片，并重置为干净画布会话；权限说明中英文资源齐全 | `validate_project.py` + `system-ui` | 首次进入相册确认权限弹窗为中文；选择一张照片导入后继续绘制 |
| F12 | 线稿 | 线稿入口、弹窗、模板加载可用 | `validate_project.py` + `swift test` + `drawing-tools` | 打开线稿并进入绘制 |

### 1.1 v0.2 下一阶段验收规划

产品经理更新后的 PRD 已进入下一阶段规划，但不属于 `v0.1.0-beta.1` 封板验收标准。T096 之后按以下编号扩展验收口径；对应功能未完成前，状态应标记为“规划中 / 待实现”，不得写成已通过。

| 编号 | 流程 | 交付标准 | 自动验证 | 人工触控 |
|---|---|---|---|---|
| N01 | 画布导航 | 默认按安全创作区居中；双指缩放 50%-300%；双指平移不让画布完全移出可视区；恢复视图可回到默认状态 | 规划新增 viewport 单测 + runtime acceptance | iPhone/iPad 双端缩放、平移、恢复视图；确认绘制、填色、取色、印章命中不偏移 |
| N02 | 内容库 | 当前页面内统一展示官方线稿、我的线稿、历史作品；官方线稿不可删除；历史和我的线稿删除语义区分 | 规划新增 `KCContentLibraryFeature` 单测 + validator | 切换分区、打开官方线稿、打开历史作品、确认入口不遮挡画布 |
| N03 | 我的线稿 | 当前画布可保存为自定义线稿；自动命名；可打开和删除；删除不影响历史作品 | 规划新增 store 单测 + runtime acceptance | 保存为线稿、从我的线稿打开、删除我的线稿、再打开历史作品 |
| N04 | 图片导入 / 拍照 | 顶部右侧和内容库入口复用同一导入服务；相册旧链路不回退；无相机设备给出降级提示 | 规划新增 system-ui / no-camera acceptance | 相册导入、拍照入口、取消、权限失败和模拟器无相机提示 |
| N05 | 离线图片生成线稿 | 白底卡通图可生成可填色位图线稿；复杂照片失败或质量差时有明确提示；不上传儿童照片 | 规划新增 pipeline 单测 + runtime acceptance 样例图 | 选择相册/拍照图片生成线稿，保存到我的线稿并打开填色 |

## 2. 必跑命令

```bash
find /Volumes/xiaoda_SSD/KidCanvas/justdraw \
  -path '*/.git' -prune -o \
  -path '*/.build' -prune -o \
  -path '*/ai-docs' -prune -o \
  -name '._*' -type f -delete

/usr/bin/python3 scripts/validate_project.py

cd Packages/KidCanvasModules
swift test

cd /Volumes/xiaoda_SSD/KidCanvas/justdraw
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' build -quiet

scripts/runtime_smoke_test.sh "iPhone 17 Pro"
scripts/runtime_smoke_test.sh "iPad Pro 11 M4"
scripts/runtime_acceptance_test.sh "iPhone 17 Pro"
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4"
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" layout-safe-area
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" layout-safe-area
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" sticker-undo-redo
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" sticker-undo-redo
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" photo-export-failure
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" photo-export-failure
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" system-ui
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" system-ui
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
- 首屏截图生成、非空检查；原始截图为竖屏 framebuffer 时生成横屏观察图。

`runtime_acceptance_test.sh` 已覆盖：

- Debug-only 运行时交互探针可启动。
- 空画布保存按钮保持可点击。
- 空画布保存不创建历史、不写入相册路径。
- 空画布保存显示本地化“先画再保存”Toast；真实保存失败仍使用“无法保存”。
- 首屏顶部工具、左侧工具栏、右侧面板、底部 Dock、折叠按钮位于 safe area 约束内。
- iPhone 横屏紧凑布局下，左侧工具栏与右侧面板保留足够可视高度，避免首屏看起来被截断或被底部 Dock 压住。
- 印章可在空白画布插入并进入选中态；删除后画布回空，撤销可恢复印章，重做可再次删除，且保存按钮仍保持可点以触发空画布“先画再保存”反馈。
- 画布生成可见画笔内容后可通过真实保存入口写入历史、显示“已保存”Toast；清空画布后打开刚保存的历史记录可恢复可见内容，且恢复后的 undo/redo 栈保持干净。
- 相册导出失败不会把 App 内历史保存回退成“无法保存”；Debug 探针会强制相册失败并验证历史已增加、当前会话已建立、失败反馈为“已保存，相册未保存”。
- 绘画工具链路可在 App 内运行时完成：24/36 色盘切换、选色高亮、画笔内容生成、橡皮擦除、线稿加载、填色、取色和最近色写入。
- 系统 UI 入口和回调可在 App 内运行时执行：Custom 打开系统取色器并通过 delegate 回填颜色，相册导入打开系统相册选择器并通过 delegate 导入合成图片；真实选色、选图和权限弹窗仍需人工点验。
- T095 画笔样张与性能基线：`brush-samples` 生成铅笔/钢笔/蜡笔横线、曲线、快线和压力渐变 PNG；`brush-perf` 输出 100/300 条 dab stroke 生成耗时 JSON。该能力用于人工视觉对比和性能回归，不替代真实手绘审美判断。

下一阶段需要新增的自动验证：

- `canvas-viewport`：覆盖默认安全创作区、缩放、平移裁剪、恢复视图以及屏幕点到画布点映射。
- `content-library`：覆盖官方线稿、我的线稿、历史作品分区状态和删除能力差异。
- `custom-line-art`：覆盖保存为线稿、打开、删除、数量上限和历史作品不受影响。
- `image-import-camera`：覆盖相册/拍照统一入口、无相机降级和权限失败文案。
- `line-art-extraction`：覆盖白底卡通图离线生成线稿、复杂图片质量提示和不使用云端服务。

## 4. 人工验收建议

交付前按 [人工验收执行表（2026-07-06）](./MANUAL_ACCEPTANCE_RUNBOOK_2026-07-06.md) 逐项记录 iPhone / iPad 结果；下面仅保留快速顺序说明。

自动化不能完全替代手指/鼠标交互，交付前建议按以下顺序快速点一遍：

1. iPhone 横屏：确认左侧工具栏可滚动，底部 Dock 不遮挡系统安全区，右侧面板不溢出。
2. iPad 横屏：确认默认横屏体验正常，主工具、颜色、历史、印章区域无遮挡。
3. 画笔：分别用铅笔、钢笔、蜡笔画线，调节尺寸后继续绘制。
4. 橡皮：切换三种形状并擦除已有内容。
5. 颜色：切换 24/36 色盘，选择颜色，打开 Custom 取自定义色。
6. 填色/取色：填色后用取色器取回颜色，再继续画线。
7. 印章：添加印章后确认蓝色选中描边与编辑按钮启用；拖动、捏合放大/缩小、双指旋转；点击前移和删除；再用撤销/重做确认印章变化可恢复。
8. 保存/历史：空画布保存应失败并显示“先画再保存”；有内容保存应显示“已保存”，并在历史中可打开/删除；如模拟器 Photos 无法确认写入系统相册，需要记录环境限制和替代证据。
9. 相册/线稿：导入照片时检查相册权限弹窗；选择照片后应替换画布并作为干净会话继续绘制；加载线稿后确认画布可继续绘制。

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
