# KidCanvas 交付验收记录（2026-07-06）

> 本记录用于 T064 交付前验收。自动验收和人工点验分开记录，不能用 runtime smoke 代替人工触控。

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
| `swift test` | 通过 | 156 tests, 0 failures |
| iPhone 17 Pro 构建 | 通过 | `xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet` |
| iPad Pro 11 M4 构建 | 通过 | `xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' build -quiet` |
| iPhone 17 Pro runtime smoke | 通过 | 启动成功、进程存活、截图非空；原始截图为竖屏 framebuffer，脚本已生成横屏观察图 `/tmp/kc_smoke_iPhone_17_Pro_landscape.png` |
| iPad Pro 11 M4 runtime smoke | 通过 | 启动成功、进程存活、截图非空；原始截图为竖屏 framebuffer，脚本已生成横屏观察图 `/tmp/kc_smoke_iPad_Pro_11_M4_landscape.png` |
| iPhone 17 Pro runtime acceptance | 通过 | 空画布保存反馈 Debug 探针：`passed=true`，保存按钮可点，失败 Toast 可见，历史 0→0 |
| iPad Pro 11 M4 runtime acceptance | 通过 | 空画布保存反馈 Debug 探针：`passed=true`，保存按钮可点，失败 Toast 可见，历史 1→1 |
| `git diff --check` | 通过 | 无空白错误 |

## 3. F01-F12 验收状态

| 编号 | 流程 | 自动验收 | 人工点验 | 当前结论 |
|---|---|---|---|---|
| F01 | 启动 | 通过 | 待点验 | 双端可安装启动，需人工确认首屏无遮挡 |
| F02 | 画笔 | 通过 | 待点验 | 需手绘铅笔/钢笔/蜡笔连续线条 |
| F03 | 橡皮 | 通过 | 待点验 | 需擦除已有内容并切三种形状 |
| F04 | 填色 | 通过 | 待点验 | 需点按封闭区域确认填色 |
| F05 | 取色 | 通过 | 待点验 | 需从画布取色并继续绘制 |
| F06 | 印章 | 通过 | 待点验 | 需确认选中反馈、拖动、捏合、旋转、前移、删除、撤销/重做 |
| F07 | 颜色面板 | 通过 | 待点验 | 需切换 24/36 色并选色 |
| F08 | 自定义色 | 通过 | 待点验 | 需打开系统取色器选择自定义颜色 |
| F09 | 保存 | 通过 | 待点验 | 需确认空画布“无法保存”、非空画布“已保存”、历史与系统相册 |
| F10 | 历史 | 通过 | 待点验 | 需保存后打开/删除历史 |
| F11 | 相册导入 | 通过 | 待点验 | 需确认权限弹窗、选择照片、导入后干净会话 |
| F12 | 线稿 | 通过 | 待点验 | 需加载线稿后继续绘制 |

## 4. 已确认改动

- T061：编辑器按钮视觉第二轮精修已完成自动验收，统一选中态、禁用态和按钮 token。
- T062：印章交互反馈优化已完成代码和自动验收，真实双指手势仍需人工点验。
- T063：相册导入/保存链路代码检查和自动验收通过；保存 Toast 已补齐双语文字，中文默认显示“已保存 / 无法保存”。
- T065：修复空画布保存反馈不可触发；保存按钮空画布时视觉弱化但保持可点击，点击后显示“无法保存”；`scripts/runtime_acceptance_test.sh` 已在 iPhone/iPad 通过。
- T066：横屏安全区与 smoke 截图归一化已完成自动验收；App 启动请求横屏 scene geometry，浮动控件改用 safe area 约束，`runtime_smoke_test.sh` 会生成横屏观察图便于首屏无遮挡人工检查。

## 5. 当前风险

| 等级 | 风险 | 处理方式 |
|---|---|---|
| 阻塞 | 暂无自动验收发现的阻塞问题 | 人工点验如发现阻塞，回写看板为新任务 |
| 非阻塞 | 系统 Photos 选择器、权限弹窗和保存到系统相册无法由 runtime smoke 证明 | 需要在 iPhone/iPad 模拟器或真机手动完成 |
| 非阻塞 | 烟测截图中保留了历史画布内容 | 人工验收前新建画布即可，不影响构建和启动结论 |
| 非阻塞 | `simctl io screenshot` 在当前 Simulator 上输出竖屏 framebuffer | 已由 smoke 脚本生成 `_landscape.png` 横屏观察图；最终仍以人工在模拟器窗口/真机横屏点验为准 |

## 6. 阶段结论

当前代码已达到“自动验收通过、可进入人工完整点验”的状态；还不能直接宣称“完全可交付给用户试用”，原因是 T064 要求的 iPhone/iPad 手工触控和 T063 的系统相册弹窗/选图/写入尚未完成。
