# KidCanvas 人工验收执行表（2026-07-06）

> 用途：交付前在 iPhone 和 iPad 上逐项点验核心绘画链路。自动验收通过只能证明代码路径可运行；系统弹窗、真实触控手势、相册写入和首屏观感仍必须人工确认。

## 1. 前置条件

| 项目 | 要求 | 结果 |
|---|---|---|
| 分支 | `main` | 待填写 |
| 语言 | 默认简体中文，英文资源保留 | 待填写 |
| 设备 1 | iPhone 17 Pro 模拟器或真机 | 待填写 |
| 设备 2 | iPad Pro 11 M4 模拟器或真机 | 待填写 |
| 方向 | 横屏优先；iPhone 与 iPad 都必须可用 | 待填写 |
| 构建 | Debug 或交付前验证包均可，需记录来源 | 待填写 |

## 2. 执行前自动验收

先执行以下命令，全部通过后再开始人工点验：

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
scripts/runtime_acceptance_test.sh "iPhone 17 Pro"
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4"
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" layout-safe-area
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" layout-safe-area
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" sticker-undo-redo
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" sticker-undo-redo
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" system-ui
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" system-ui
git diff --check
```

| 命令组 | 结果 | 证据/备注 |
|---|---|---|
| 工程静态校验 | 待填写 |  |
| Swift Package 测试 | 待填写 |  |
| iPhone 构建与运行时验收 | 待填写 |  |
| iPad 构建与运行时验收 | 待填写 |  |
| 截图与空白检查 | 待填写 |  |

## 3. F01-F12 人工点验

| 编号 | 流程 | 人工步骤 | 预期结果 | iPhone 结果 | iPad 结果 | 证据/备注 |
|---|---|---|---|---|---|---|
| F01 | 启动 | 启动 App，切到横屏，观察首屏。 | App 不崩溃；画布、左侧工具栏、右侧面板、底部 Dock 均可见且无遮挡。 | 待填写 | 待填写 |  |
| F02 | 画笔 | 依次选择铅笔、钢笔、蜡笔；拖动尺寸滑杆；画连续线条。 | 三种画笔都能绘制；尺寸变化可感知；撤销按钮状态正确。 | 待填写 | 待填写 |  |
| F03 | 橡皮 | 先画几笔，再切换橡皮 circle/cloud/star，调整尺寸并擦除。 | 三种形状切换有效；擦除区域符合预期；可撤销。 | 待填写 | 待填写 |  |
| F04 | 填色 | 选择线稿或手动画封闭区域，切到填色后点按区域。 | 封闭区域被填色；未明显污染画布外区域；可撤销。 | 待填写 | 待填写 |  |
| F05 | 取色 | 在已有颜色区域上使用取色器，再切回画笔绘制。 | 当前色更新为取到的颜色；后续画笔使用该颜色。 | 待填写 | 待填写 |  |
| F06 | 印章 | 添加印章，拖动、捏合放大/缩小、双指旋转、前移、删除，再撤销/重做。 | 印章选中反馈清楚；真实手势有效；删除和撤销/重做链路正确。 | 待填写 | 待填写 |  |
| F07 | 颜色面板 | 切换 24/36 色盘，选择多个颜色，观察最近色和当前色。 | 色盘切换正常；选中色高亮正确；最近色顺序更新。 | 待填写 | 待填写 |  |
| F08 | 自定义色 | 点击 Custom，打开系统取色器并选择颜色。 | 仅有一个 Custom 入口；系统取色器可打开；选择后当前色更新。 | 待填写 | 待填写 |  |
| F09 | 保存 | 空画布点击保存；画一笔后再保存；查看系统相册。 | 空画布显示“无法保存”；非空画布显示“已保存”；系统相册可看到保存图片或记录环境限制。 | 待填写 | 待填写 |  |
| F10 | 历史 | 保存后打开历史，进入刚保存记录，再删除记录。 | 缩略图可见；打开后画布恢复；删除后列表刷新。 | 待填写 | 待填写 |  |
| F11 | 相册导入 | 首次打开相册导入，确认权限弹窗；选择一张照片导入。 | 权限说明为中文；照片进入画布；导入后作为干净会话继续绘制。 | 待填写 | 待填写 |  |
| F12 | 线稿 | 打开线稿入口，选择任一线稿，继续绘制/填色。 | 弹窗展示正常；线稿加载到画布；后续绘制和填色可用。 | 待填写 | 待填写 |  |

## 4. 系统能力专项点验

| 能力 | 人工步骤 | 必须记录 | 结果 |
|---|---|---|---|
| Photos 权限弹窗 | 清理权限或首次安装后进入相册导入。 | 弹窗语言、按钮、是否能继续导入。 | 待填写 |
| 从相册导入图片 | 选择模拟器或真机相册中的一张图片。 | 图片是否进入画布、是否可继续绘制、导入后撤销/重做是否干净。 | 待填写 |
| 保存到系统相册 | 非空画布保存后打开 Photos 检查。 | 是否写入 Photos；如模拟器环境无法确认，记录替代证据和限制。 | 待填写 |
| 系统自定义取色器 | 点击 Custom 后选择任意颜色。 | 取色器是否出现、颜色是否回填、最近色是否更新。 | 待填写 |
| 印章真实捏合/旋转 | 触控板、鼠标模拟多指或真机双指操作。 | 缩放上下限、旋转流畅度、选中框和编辑按钮是否跟随。 | 待填写 |

## 5. 缺陷记录模板

发现问题时按以下格式回写到看板或交付记录：

```text
缺陷编号：
等级：阻塞 / 非阻塞
设备：iPhone / iPad / 真机 / 模拟器
系统版本：
复现步骤：
实际结果：
预期结果：
截图或录屏路径：
是否影响明天交付：是 / 否
建议处理任务：
```

## 6. 验收结论

| 项目 | 结论 | 备注 |
|---|---|---|
| iPhone 人工点验 | 待填写 |  |
| iPad 人工点验 | 待填写 |  |
| 系统能力专项 | 待填写 |  |
| 阻塞缺陷 | 待填写 |  |
| 非阻塞缺陷 | 待填写 |  |
| 是否可交付试用 | 待填写 |  |
