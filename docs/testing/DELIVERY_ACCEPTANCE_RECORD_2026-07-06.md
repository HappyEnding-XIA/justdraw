# KidCanvas 交付验收记录（2026-07-06）

> 本记录用于 T064 交付前验收及后续自动验收补强。自动验收和人工点验分开记录，不能用 runtime smoke 代替人工触控。

## 1. 验收环境

| 项目 | 记录 |
|---|---|
| 分支 | `main` |
| 设备 1 | iPhone 17 Pro，UDID `A4306B68-8A41-47A1-AE01-18EC93F51694` |
| 设备 2 | iPad Pro 11 M4，UDID `89B67EE3-75AB-4E06-BD8C-BC1B52339E0A` |
| 方向 | 横屏优先；工程仍支持 iPhone + iPad |
| 语言 | 默认简体中文，英文资源保留 |
| 烟测截图 | 原始截图：`/tmp/kc_smoke_iPhone_17_Pro.png`、`/tmp/kc_smoke_iPad_Pro_11_M4.png`；横屏观察图：`/tmp/kc_smoke_iPhone_17_Pro_landscape.png`、`/tmp/kc_smoke_iPad_Pro_11_M4_landscape.png` |

## 2. 自动验收结果

| 验收项 | 结果 | 备注 |
|---|---|---|
| 清理 AppleDouble 文件 | 通过 | 已排除 `.git`、`.build`、`ai-docs` |
| `python3 scripts/validate_project.py` | 通过 | 覆盖工程配置、Swift-first、模块治理、本地化、保存/相册结构检查 |
| `swift test` | 通过 | 157 tests, 0 failures |
| iPhone 17 Pro 构建 | 通过 | `xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet` |
| iPad Pro 11 M4 构建 | 通过 | `xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' build -quiet` |
| iPhone 17 Pro runtime smoke | 通过 | 启动成功、进程存活、截图非空；原始截图为竖屏 framebuffer，脚本已生成横屏观察图 `/tmp/kc_smoke_iPhone_17_Pro_landscape.png` |
| iPad Pro 11 M4 runtime smoke | 通过 | 启动成功、进程存活、截图非空；原始截图为竖屏 framebuffer，脚本已生成横屏观察图 `/tmp/kc_smoke_iPad_Pro_11_M4_landscape.png` |
| iPhone 17 Pro runtime acceptance | 通过 | 空画布保存反馈 Debug 探针：`passed=true`，保存按钮可点，失败 Toast 可见，历史数量不变 |
| iPad Pro 11 M4 runtime acceptance | 通过 | 空画布保存反馈 Debug 探针：`passed=true`，保存按钮可点，失败 Toast 可见，历史数量不变 |
| iPhone 17 Pro runtime layout acceptance | 通过 | 首屏 safe area Debug 探针：`passed=true`，顶部工具、左侧工具栏、右侧面板、底部 Dock、折叠按钮均未越界；左栏可视高 221.7pt，右侧面板可视高 220pt |
| iPad Pro 11 M4 runtime layout acceptance | 通过 | 首屏 safe area Debug 探针：`passed=true`，顶部工具、左侧工具栏、右侧面板、底部 Dock、折叠按钮均未越界；左栏可视高 357.5pt，右侧面板可视高 495pt |
| iPhone 17 Pro runtime sticker acceptance | 通过 | 印章删除/撤销/重做 Debug 探针：`passed=true`，覆盖空白画布插入印章、选中态、删除、撤销恢复、重做删除 |
| iPad Pro 11 M4 runtime sticker acceptance | 通过 | 印章删除/撤销/重做 Debug 探针：`passed=true`，覆盖空白画布插入印章、选中态、删除、撤销恢复、重做删除 |
| iPhone 17 Pro runtime save/history acceptance | 通过 | 绘制内容保存与历史恢复 Debug 探针：`passed=true`，覆盖画笔内容可见、保存成功 Toast、历史数量 +1、清空后打开历史恢复可见内容 |
| iPad Pro 11 M4 runtime save/history acceptance | 通过 | 绘制内容保存与历史恢复 Debug 探针：`passed=true`，覆盖画笔内容可见、保存成功 Toast、历史数量 +1、清空后打开历史恢复可见内容 |
| 双端 runtime layout 并行验收 | 通过 | T072 后 iPhone 17 Pro 与 iPad Pro 11 M4 `layout-safe-area` 可并行执行，默认 DerivedData 路径按设备和探针拆分，未再出现 build.db locked |
| iPhone 17 Pro runtime drawing-tools acceptance | 通过 | 绘画工具链路 Debug 探针：`passed=true`，覆盖 24/36 色盘切换、选色高亮、画笔内容、橡皮擦除、线稿加载、填色、取色和最近色写入 |
| iPad Pro 11 M4 runtime drawing-tools acceptance | 通过 | 绘画工具链路 Debug 探针：`passed=true`，覆盖 24/36 色盘切换、选色高亮、画笔内容、橡皮擦除、线稿加载、填色、取色和最近色写入 |
| iPhone 17 Pro runtime system-ui acceptance | 通过 | 系统 UI Debug 探针：`passed=true`，验证 Custom 系统取色器可呈现并回填颜色，相册选择器可呈现并导入合成图片 |
| iPad Pro 11 M4 runtime system-ui acceptance | 通过 | 系统 UI Debug 探针：`passed=true`，验证 Custom 系统取色器可呈现并回填颜色，相册选择器可呈现并导入合成图片 |
| T077 交付前自动预验收 | 通过 | 2026-07-06 23:03-23:10 重跑 `validate_project.py`、`swift test`、双端 smoke、双端 `drawing-tools`、双端 `system-ui`、`git diff --check`；最新横屏截图人工查看未见明显遮挡 |
| T077 人工验收环境准备 | 完成 | iPhone/iPad 模拟器已加入 `AppIcon-1024.png` 相册测试图，已 reset Photos 权限，已启动 App；Codex 当前无 macOS 辅助功能权限，无法代替人工点击 Simulator |
| `git diff --check` | 通过 | 无空白错误 |

## 3. F01-F12 验收状态

人工点验执行表已补齐：[KidCanvas 人工验收执行表（2026-07-06）](./MANUAL_ACCEPTANCE_RUNBOOK_2026-07-06.md)。2026-07-10 用户确认人工验收全部通过，本记录同步收口阶段结论。

| 编号 | 流程 | 自动验收 | 人工点验 | 当前结论 |
|---|---|---|---|---|
| F01 | 启动 | 通过 | 通过 | 双端可安装启动，首屏无遮挡 |
| F02 | 画笔 | 通过 | 通过 | 铅笔/钢笔/蜡笔可绘制，尺寸和撤销状态正常 |
| F03 | 橡皮 | 通过 | 通过 | 三种橡皮形状可切换并擦除 |
| F04 | 填色 | 通过 | 通过 | 封闭区域填色正常 |
| F05 | 取色 | 通过 | 通过 | 取色后当前色更新并可继续绘制 |
| F06 | 印章 | 通过 | 通过 | 选中、拖动、捏合、旋转、前移、删除、撤销/重做通过 |
| F07 | 颜色面板 | 通过 | 通过 | 24/36 色盘、选中色、最近色通过 |
| F08 | 自定义色 | 通过 | 通过 | 系统取色器打开和颜色回填通过 |
| F09 | 保存 | 通过 | 通过 | 空画布提示、非空保存、历史与系统相册通过 |
| F10 | 历史 | 通过 | 通过 | 保存后打开/删除历史通过 |
| F11 | 相册导入 | 通过 | 通过 | 权限弹窗、选图导入、干净会话通过 |
| F12 | 线稿 | 通过 | 通过 | 线稿加载后绘制/填色通过 |

## 4. 已确认改动

- T061：编辑器按钮视觉第二轮精修已完成自动验收，统一选中态、禁用态和按钮 token。
- T062：印章交互反馈优化已完成代码、自动验收和人工点验，真实双指手势通过。
- T063：相册导入/保存链路代码检查、自动验收和人工点验通过；保存 Toast 已补齐双语文字，中文默认显示“已保存 / 无法保存”。
- T065：修复空画布保存反馈不可触发；保存按钮空画布时视觉弱化但保持可点击，点击后显示“无法保存”；`scripts/runtime_acceptance_test.sh` 已在 iPhone/iPad 通过。
- T066：横屏安全区与 smoke 截图归一化已完成自动验收；App 启动请求横屏 scene geometry，浮动控件改用 safe area 约束，`runtime_smoke_test.sh` 会生成横屏观察图便于首屏无遮挡人工检查。
- T067：新增首屏 safe area 运行时验收探针；`scripts/runtime_acceptance_test.sh "iPhone 17 Pro" layout-safe-area` 与 `scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" layout-safe-area` 均通过，可自动检查关键浮动控件是否越过安全区。
- T068：收口 iPhone 横屏紧凑布局；左侧工具栏上移并增加可视高度，右侧面板上移，底部 Dock 和画笔卡片略收紧；新增 runtime 探针对左栏/右栏最低可视高度做防回归检查。
- T069：新增印章删除/撤销/重做运行时验收探针；`scripts/runtime_acceptance_test.sh "iPhone 17 Pro" sticker-undo-redo` 与 `scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" sticker-undo-redo` 均通过，可自动检查印章插入、选中、删除、撤销恢复和重做删除链路。
- T070：新增绘制内容保存与历史恢复运行时验收探针；`scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore` 与 `scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore` 均通过，可自动检查画笔内容可见、保存成功、历史写入和打开恢复链路。
- T071：首屏视觉与面板裁切精修已完成自动验收；iPhone 左侧工具栏不再露出半个按钮，右侧面板可视高度提升到 220pt，24 色盘首屏完整显示，底部 Dock 略收紧，浮层/按钮边界更清晰；iPhone/iPad `layout-safe-area` 和 runtime smoke 均通过。
- T072：运行时验收脚本默认 DerivedData 路径改为按设备名和探针名区分，保留 `DERIVED_DATA` 手动覆盖；双端 `layout-safe-area` 并行执行已通过，避免后续自测因 Xcode build.db 锁误报失败。
- T073：新增绘画工具链路运行时验收探针；`scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools` 与 `scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools` 均通过，可自动检查色盘切换、选色高亮、画笔、橡皮、线稿、填色、取色和最近色链路。
- T074：补齐交付前人工验收执行表，覆盖 iPhone/iPad 双端 F01-F12、Photos 权限/导入/保存、系统取色器、印章真实捏合/旋转和缺陷记录模板；2026-07-10 用户确认人工验收全部通过。
- T075：运行时烟测脚本默认 DerivedData 路径改为按设备名区分，保留 `DERIVED_DATA` 手动覆盖；双端 smoke 并行执行已通过，避免共用 `/tmp/kc-dd` 导致 Xcode build.db 锁误报失败。
- T076：新增系统 UI 呈现与回调运行时验收探针；`scripts/runtime_acceptance_test.sh "iPhone 17 Pro" system-ui` 与 `scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" system-ui` 均通过，可自动检查 Custom 系统取色器呈现与颜色回填、相册选择器呈现与合成图片导入；探针结束后会清理回空白会话，避免污染后续 smoke 截图；真实选色/选图/权限弹窗已由用户人工确认通过。
- T077：交付前自动预验收与人工点验均已完成；执行表已记录 `main` / `origin/main` 最新提交、双端模拟器 UDID、自动验收结果、相册测试图注入、Photos 权限 reset 状态和用户人工验收通过结论。

## 5. 当前风险

| 等级 | 风险 | 处理方式 |
|---|---|---|
| 阻塞 | 暂无 | 自动验收与人工验收均未反馈阻塞问题 |
| 非阻塞 | T110 顶部调色盘入口代码变量仍命名为 `brandButton` | 功能语义、图标、accessibility、本地化已通过；建议后续小修命名为 `paletteButton` 并补 validator |
| 已关闭 | 系统 Photos 选择器、权限弹窗和保存到系统相册无法由 runtime smoke 证明 | 2026-07-10 用户确认人工验收通过 |
| 已关闭 | 系统自定义取色器弹窗无法由 Debug 探针替代真实手动选择 | 2026-07-10 用户确认人工验收通过 |
| 非阻塞 | `simctl io screenshot` 在当前 Simulator 上输出竖屏 framebuffer | 已由 smoke 脚本生成 `_landscape.png` 横屏观察图；最终仍以人工在模拟器窗口/真机横屏点验为准 |
| 已关闭 | 当前 Codex 进程未获 macOS 辅助功能权限，无法代替人工点击 Simulator | 2026-07-10 用户已完成人工验收并确认通过 |

## 6. 阶段结论

当前代码已达到“自动验收通过、人工验收通过”的状态，可以作为本阶段可交付试用版本收口。剩余非阻塞小修：T110 顶部调色盘入口代码变量命名从 `brandButton` 收敛为颜色面板语义命名，并补防回流。
