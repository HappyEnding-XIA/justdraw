# 运行时烟测（Runtime Smoke Test）

> 静态验收（`swift test` + `validate_project.py` + `xcodebuild build`）通过后，用 `scripts/runtime_smoke_test.sh` 验证 app 能真正在模拟器里启动并稳定运行。静态验收只能证明"能编译"，运行时烟测证明"能启动、不崩溃、UI 能渲染"。
>
> 交互和布局类回归可使用 `scripts/runtime_acceptance_test.sh`。该脚本通过 Debug-only launch argument 触发 App 内部验收探针，并从模拟器沙盒读取 JSON 结果；当前覆盖空画布保存反馈、首屏 safe area 布局、印章删除/撤销/重做链路、绘制内容保存与历史恢复链路、相册导出失败语义、绘画工具链路，以及系统 UI 呈现探针。

## 何时必须跑

- 改动 App target Sources（`KidCanvas/*.swift`）或 `project.pbxproj` 之后。
- OC→Swift 转换、bridge 改动、App 生命周期改动之后。
- 怀疑运行时回归时（静态构建无法发现启动崩溃、selector 不匹配等）。

## 用法

```bash
# 默认 iPhone 17 Pro
scripts/runtime_smoke_test.sh

# 指定设备
scripts/runtime_smoke_test.sh "iPad Pro 11 M4"

# 空画布保存反馈交互验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro"
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4"

# 首屏 safe area 布局验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" layout-safe-area
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" layout-safe-area

# 印章删除、撤销、重做验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" sticker-undo-redo
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" sticker-undo-redo

# 绘制内容保存与历史恢复验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore

# 相册导出失败语义验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" photo-export-failure
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" photo-export-failure

# 绘画工具链路验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools

# 系统取色器与相册选择器入口验收
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" system-ui
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" system-ui
```

脚本流程：清理 `._*` → 按设备名解析 UDID → 启动设备 → Debug 构建 → 安装 → 启动 → 轮询进程存活 → 等待 UI 渲染 → 重试截图直到文件大小达到阈值 → 必要时生成横屏观察图 → 截图到 `/tmp/kc_smoke_<device>.png`。

可选环境变量：

- `CONFIGURATION`：构建配置，默认 `Debug`。
- `DERIVED_DATA`：构建产物目录。`runtime_smoke_test.sh` 默认 `/tmp/kc-dd-smoke-<设备名>`；`runtime_acceptance_test.sh` 默认 `/tmp/kc-dd-acceptance-<设备名>-<探针名>`，避免 iPhone/iPad 或多个探针并行执行时抢同一个 Xcode build database。
- `SCREENSHOT_DIR`：截图输出目录，默认 `/tmp`。
- `SCREENSHOT_WAIT_SECONDS`：启动成功后等待 UI 渲染的秒数，默认 `3`。
- `SCREENSHOT_RETRY_COUNT`：截图最大重试次数，默认 `5`。
- `SCREENSHOT_RETRY_INTERVAL`：截图过小时的重试间隔秒数，默认 `1`。
- `SCREENSHOT_MIN_BYTES`：截图最小文件大小阈值，默认 `20000`。
- `LAUNCH_TIMEOUT_SECONDS`：`simctl launch` 最大等待秒数，默认 `30`。
- `NORMALIZE_LANDSCAPE_SCREENSHOT`：原始截图为竖屏 framebuffer 时，是否额外生成 `_landscape.png` 横屏观察图，默认 `1`。
- `runtime_acceptance_test.sh` 额外支持 `WAIT_SECONDS`：等待 App 写出验收 JSON 的最长秒数，默认 `10`。

需要固定构建目录时，可以显式传入 `DERIVED_DATA=/tmp/kc-dd-custom`；此时脚本会尊重该路径，调用方需自行避免并行构建锁。交付验收默认不要共用同一个 DerivedData 路径并行跑双端 smoke 或 acceptance。

以上数值型环境变量都必须是大于 0 的整数，`NORMALIZE_LANDSCAPE_SCREENSHOT` 必须是 `0` 或 `1`，否则脚本会以退出码 `8` 结束。

## 退出码

| 码 | 含义 |
|---|---|
| 0 | 烟测通过 |
| 2 | 指定设备不存在 |
| 3 | 构建失败（日志 `/tmp/kc_smoke_build.log`）|
| 4 | 找不到产物 `.app` |
| 5 | 启动失败或启动超时（常见 `FBSOpenApplication` code 4 / CoreSimulator 卡住）|
| 6 | 启动后进程未存活（崩溃）|
| 7 | 截图为空或过小，UI 可能尚未渲染完成 |
| 8 | 环境变量配置非法 |
| 9 | 无法读取截图尺寸或无法生成横屏观察图 |

`runtime_acceptance_test.sh` 的第二个参数为探针名，默认 `empty-save`，可选：

- `empty-save`：空画布保存反馈。
- `layout-safe-area`：首屏浮动控件是否落在 safe area 约束内，并检查 iPhone 横屏紧凑布局下左侧工具栏、右侧面板的最低可视高度。
- `sticker-undo-redo`：空白画布插入印章后检查选中态、可保存状态，再删除印章并验证撤销可恢复、重做可再次删除。
- `save-history-restore`：空白画布插入一条 Debug-only 画笔笔触，通过真实保存入口写入历史并触发成功 Toast，再清空画布并从历史恢复可见内容。脚本会在启动前对模拟器授予 `photos-add` 权限，避免系统相册权限弹窗干扰自动验收。
- `photo-export-failure`：空白画布插入一条 Debug-only 画笔笔触，通过真实保存入口写入历史，并在 Debug launch arg 下强制相册导出失败；探针验证历史数增加、当前会话建立、已观察到“已保存”，且失败反馈为“已保存，相册未保存”，不得出现“无法保存”来否定本地保存。
- `drawing-tools`：空白画布切换 24/36 色盘并选色，生成画笔内容，执行橡皮擦除，加载线稿后填色，再用取色器采样并写入最近色。该探针覆盖画笔、橡皮、颜色面板、填色、取色和线稿加载的 App 内运行时链路。
- `system-ui`：验证 Custom 能呈现 `UIColorPickerViewController`，并通过系统取色器 delegate 回填颜色和最近色；验证相册导入能呈现 `UIImagePickerController(.photoLibrary)`，并通过图片选择 delegate 导入一张合成图片且保持干净会话。该系统 UI 呈现探针不能替代人工选择真实颜色、真实照片和权限弹窗检查。

`runtime_acceptance_test.sh` 的补充退出码：

| 码 | 含义 |
|---|---|
| 6 | 未生成验收 JSON |
| 7 | 验收 JSON 中 `passed` 为 false |

## 故障排查

### 设备不存在

`xcrun simctl list devices available` 查看可用设备名，确保拼写一致。脚本失败时会打印前 20 行可用设备。

### CoreSimulator 卡住（`FBSOpenApplication Error Code 4`）

**通常不是代码问题**——宿主机 CoreSimulator / LaunchServices 数据库（LSDB）被污染时，所有 app（含原 OC 版）都无法启动。特征：`simctl launch` 返回 code 4，且引用已删除的镜像路径。

处理（按代价从低到高）：

1. `xcrun simctl shutdown all` 后重试。
2. `xcrun simctl erase all`（清空所有模拟器数据，会丢已安装 app）。
3. `killall -9 com.apple.CoreSimulator.CoreSimulatorService` 后重试。
4. **重启 Mac**（本项目 2026-06-26 遇到的 LSDB 污染最终靠重启清除）。

教训：永远不要用 `find` 匹配 `Index.noindex` 镜像路径做 `simctl install`——会污染 bundle id 的 LSDB 解析。只用 `DerivedData/Build/Products/<config>-iphonesimulator/<App>.app` 的真实产物路径。

### bundle id 启动失败

确认 `Info.plist` 的 `CFBundleIdentifier` 与脚本里 `BUNDLE_ID` 一致（当前 `com.kidcanvas.drawing`）。

### 启动后崩溃（进程未存活）

抓崩溃日志：

```bash
xcrun simctl spawn "<UDID>" log stream --predicate 'process == "KidCanvas"' --level debug
```

对照改动定位。OC→Swift 转换若有备份（`/tmp/*.bak`），可对比转换前后行为。

### 截图过小或白屏

脚本会先等待 `SCREENSHOT_WAIT_SECONDS`，再最多重试 `SCREENSHOT_RETRY_COUNT` 次截图，并用 `SCREENSHOT_MIN_BYTES` 过滤明显空白或未渲染完成的截图。iPad 模拟器偶发启动早期白屏时，可临时调大等待时间：

```bash
SCREENSHOT_WAIT_SECONDS=6 SCREENSHOT_RETRY_COUNT=8 scripts/runtime_smoke_test.sh "iPad Pro 11 M4"
```

### 原始截图不是横屏比例

某些 Simulator 设备即使 App scene 已是横屏，`simctl io screenshot` 得到的原始 framebuffer 仍可能是竖屏比例。脚本默认会额外生成 `_landscape.png` 横屏观察图供人工查看，例如：

```text
/tmp/kc_smoke_iPhone_17_Pro_landscape.png
/tmp/kc_smoke_iPad_Pro_11_M4_landscape.png
```

只在排查截图旋转本身时临时关闭：

```bash
NORMALIZE_LANDSCAPE_SCREENSHOT=0 scripts/runtime_smoke_test.sh "iPhone 17 Pro"
```

### 外置盘 AppleDouble 文件

项目放在外置盘时，macOS 可能生成 `._*` AppleDouble 元数据文件。`.build` 内部的 `._*` 属于构建目录噪声，不提交即可；源码、文档、脚本和 Xcode 工程目录下的 `._*` 必须清理。

验收前可执行：

```bash
find /Volumes/xiaoda_SSD/KidCanvas/justdraw \
  -path '*/.git' -prune -o \
  -path '*/.build' -prune -o \
  -path '*/ai-docs' -prune -o \
  -name '._*' -type f -print
```

应无输出；如有输出，确认不是 `.git` / `.build` / `ai-docs` 后删除再跑 `/usr/bin/python3 scripts/validate_project.py`。

## 环境依赖

- Xcode 命令行工具（`xcode-select -p`）
- `/usr/bin/python3`（macOS 系统 Python；运行脚本默认优先使用它解析 `simctl list -j` 的 JSON，也可通过 `PYTHON_BIN=/path/to/python3` 覆盖）
- 无其他重依赖。
