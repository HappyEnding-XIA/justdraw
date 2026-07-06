#!/usr/bin/env bash
#
#  runtime_smoke_test.sh
#  KidCanvas
#
#  运行时烟测：构建 → 安装到模拟器 → 启动 → 进程存活检查 → 截图。
#  Created by 小大 on 2026/06/26.
#
#  用法：
#    scripts/runtime_smoke_test.sh                    # 默认 iPhone 17 Pro
#    scripts/runtime_smoke_test.sh "iPad Pro 11 M4"
#
#  故障排查见 docs/testing/RUNTIME_SMOKE_TEST.md。
#

set -euo pipefail

DEVICE_NAME="${1:-iPhone 17 Pro}"
SCHEME="KidCanvas"
BUNDLE_ID="com.kidcanvas.drawing"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/kc-dd}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-/tmp}"
SCREENSHOT_WAIT_SECONDS="${SCREENSHOT_WAIT_SECONDS:-3}"
SCREENSHOT_RETRY_COUNT="${SCREENSHOT_RETRY_COUNT:-5}"
SCREENSHOT_RETRY_INTERVAL="${SCREENSHOT_RETRY_INTERVAL:-1}"
SCREENSHOT_MIN_BYTES="${SCREENSHOT_MIN_BYTES:-20000}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-30}"

# 项目根目录（本脚本位于 <root>/scripts/）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$PROJECT_ROOT/KidCanvas.xcodeproj"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m%s\033[0m\n' "$*"; }
step()  { blue "▶ $*"; }

# 1. 清理外置盘 AppleDouble 临时文件（validator 会把 ._*.m 当成 OC 源码导致假失败）。
step "清理 ._*/.!* 临时文件"
find "$PROJECT_ROOT" -type f \( -name '._*' -o -name '.!*' \) -delete 2>/dev/null || true

# 2. 按设备名解析 UDID（跨 runtime 取第一个匹配）。
UDID="$(xcrun simctl list devices available -j \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(next((t['udid'] for rt in d['devices'].values() for t in rt if t.get('name')=='$DEVICE_NAME'), ''))")"

if [ -z "$UDID" ]; then
  red "错误：找不到可用模拟器 '$DEVICE_NAME'。"
  red "可用设备（前 20 行）："
  xcrun simctl list devices available | grep -E "iPhone|iPad" | head -20
  exit 2
fi
green "设备: $DEVICE_NAME ($UDID)"

# 3. 启动并等待就绪（已启动则跳过）。
step "启动模拟器"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null 2>&1 || true

# 4. 构建。
step "构建 $SCHEME ($CONFIGURATION)"
if ! xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
      -configuration "$CONFIGURATION" \
      -derivedDataPath "$DERIVED_DATA" \
      build >/tmp/kc_smoke_build.log 2>&1; then
  red "构建失败，完整日志见 /tmp/kc_smoke_build.log，末尾 20 行："
  tail -20 /tmp/kc_smoke_build.log
  exit 3
fi
green "构建成功"

APP="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphonesimulator/KidCanvas.app"
if [ ! -d "$APP" ]; then
  red "找不到产物 .app: $APP"
  exit 4
fi

# 5. 安装。
step "安装到 $DEVICE_NAME"
xcrun simctl install "$UDID" "$APP"

# 6. 启动并捕获输出（启动失败通常是 FBS code 4，属宿主机环境问题）。
step "启动 $BUNDLE_ID"
LAUNCH_OUT_FILE="$(mktemp /tmp/kc_smoke_launch.XXXXXX)"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >"$LAUNCH_OUT_FILE" 2>&1 &
LAUNCH_PID="$!"
launch_elapsed=0
while kill -0 "$LAUNCH_PID" 2>/dev/null; do
  if [ "$launch_elapsed" -ge "$LAUNCH_TIMEOUT_SECONDS" ]; then
    kill "$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
    LAUNCH_OUT="$(cat "$LAUNCH_OUT_FILE" 2>/dev/null || true)"
    rm -f "$LAUNCH_OUT_FILE"
    red "启动超时（超过 ${LAUNCH_TIMEOUT_SECONDS}s）：$LAUNCH_OUT"
    red "这通常是宿主机 CoreSimulator/LaunchServices 卡住，不一定是代码问题。"
    red "处理方法见 docs/testing/RUNTIME_SMOKE_TEST.md「CoreSimulator 卡住」。"
    exit 5
  fi
  sleep 1
  launch_elapsed=$((launch_elapsed + 1))
done

if ! wait "$LAUNCH_PID"; then
  LAUNCH_OUT="$(cat "$LAUNCH_OUT_FILE" 2>/dev/null || true)"
  rm -f "$LAUNCH_OUT_FILE"
  red "启动失败：$LAUNCH_OUT"
  red "若提示 'FBSOpenApplication Error Code 4'，通常是宿主机 CoreSimulator/"
  red "LaunchServices 数据库污染，不是代码问题（原 OC 版同样无法启动）。"
  red "处理方法见 docs/testing/RUNTIME_SMOKE_TEST.md「CoreSimulator 卡住」。"
  exit 5
fi
LAUNCH_OUT="$(cat "$LAUNCH_OUT_FILE" 2>/dev/null || true)"
rm -f "$LAUNCH_OUT_FILE"
PID="$(printf '%s' "$LAUNCH_OUT" | grep -oE '[0-9]+$' || true)"
green "启动成功，PID=$PID"

# 7. 轮询检查进程是否存活（捕获启动后立即崩溃；launchctl 注册可能有延迟，故重试）。
step "检查进程存活（最多轮询 10 秒）"
alive=0
for _ in $(seq 1 10); do
  if xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q "kidcanvas"; then
    alive=1
    break
  fi
  sleep 1
done
if [ "$alive" = 1 ]; then
  green "进程存活，启动后未崩溃"
else
  red "进程未存活——app 可能在启动后崩溃。"
  red "抓崩溃日志：xcrun simctl spawn \"$UDID\" log stream --predicate 'process == \"KidCanvas\"' --level debug"
  exit 6
fi

# 8. 截图。启动后 UI 渲染可能比进程存活稍晚，先等待再重试截图，
# 避免 iPad 偶发抓到启动早期白屏。
SHOT="$SCREENSHOT_DIR/kc_smoke_${DEVICE_NAME// /_}.png"
step "等待 UI 渲染 ${SCREENSHOT_WAIT_SECONDS}s"
sleep "$SCREENSHOT_WAIT_SECONDS"

step "截图 → $SHOT"
shot_ready=0
for attempt in $(seq 1 "$SCREENSHOT_RETRY_COUNT"); do
  xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1 || true
  shot_size=0
  if [ -f "$SHOT" ]; then
    shot_size="$(stat -f%z "$SHOT" 2>/dev/null || echo 0)"
  fi

  if [ "$shot_size" -ge "$SCREENSHOT_MIN_BYTES" ]; then
    shot_ready=1
    green "截图已保存: $SHOT (${shot_size} bytes)"
    break
  fi

  if [ "$attempt" -lt "$SCREENSHOT_RETRY_COUNT" ]; then
    blue "截图过小（${shot_size} bytes），等待 ${SCREENSHOT_RETRY_INTERVAL}s 后重试 ${attempt}/${SCREENSHOT_RETRY_COUNT}"
    sleep "$SCREENSHOT_RETRY_INTERVAL"
  fi
done

if [ "$shot_ready" != 1 ]; then
  red "截图未达到最小大小 ${SCREENSHOT_MIN_BYTES} bytes，最后文件: $SHOT"
  red "这通常表示 UI 仍未渲染完成或截图为空白，可调大 SCREENSHOT_WAIT_SECONDS / SCREENSHOT_RETRY_COUNT 后重试。"
  exit 7
fi

echo
green "✓ 运行时烟测通过 ($DEVICE_NAME)"
