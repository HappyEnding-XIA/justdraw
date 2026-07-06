# 运行时烟测（Runtime Smoke Test）

> 静态验收（`swift test` + `validate_project.py` + `xcodebuild build`）通过后，用 `scripts/runtime_smoke_test.sh` 验证 app 能真正在模拟器里启动并稳定运行。静态验收只能证明"能编译"，运行时烟测证明"能启动、不崩溃、UI 能渲染"。

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
```

脚本流程：清理 `._*` → 按设备名解析 UDID → 启动设备 → Debug 构建 → 安装 → 启动 → 轮询进程存活 → 等待 UI 渲染 → 重试截图直到文件大小达到阈值 → 截图到 `/tmp/kc_smoke_<device>.png`。

可选环境变量：

- `CONFIGURATION`：构建配置，默认 `Debug`。
- `DERIVED_DATA`：构建产物目录，默认 `/tmp/kc-dd`。
- `SCREENSHOT_DIR`：截图输出目录，默认 `/tmp`。
- `SCREENSHOT_WAIT_SECONDS`：启动成功后等待 UI 渲染的秒数，默认 `3`。
- `SCREENSHOT_RETRY_COUNT`：截图最大重试次数，默认 `5`。
- `SCREENSHOT_RETRY_INTERVAL`：截图过小时的重试间隔秒数，默认 `1`。
- `SCREENSHOT_MIN_BYTES`：截图最小文件大小阈值，默认 `20000`。
- `LAUNCH_TIMEOUT_SECONDS`：`simctl launch` 最大等待秒数，默认 `30`。

以上数值型环境变量都必须是大于 0 的整数，否则脚本会以退出码 `8` 结束。

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

应无输出；如有输出，确认不是 `.git` / `.build` / `ai-docs` 后删除再跑 `python3 scripts/validate_project.py`。

## 环境依赖

- Xcode 命令行工具（`xcode-select -p`）
- `python3`（macOS 自带，用于解析 `simctl list -j` 的 JSON；`validate_project.py` 同样依赖）
- 无其他重依赖。
