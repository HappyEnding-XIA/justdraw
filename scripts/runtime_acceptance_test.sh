#!/usr/bin/env bash
#
#  runtime_acceptance_test.sh
#  KidCanvas
#
#  运行时交互验收：构建 → 安装 → 带 Debug 探针参数启动 → 读取沙盒 JSON 结果。
#  Created by 小大 on 2026/07/06.
#

set -euo pipefail

DEVICE_NAME="${1:-iPhone 17 Pro}"
PROBE="${2:-empty-save}"
SCHEME="KidCanvas"
BUNDLE_ID="com.kidcanvas.drawing"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/kc-dd-acceptance}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$PROJECT_ROOT/KidCanvas.xcodeproj"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m%s\033[0m\n' "$*"; }
step()  { blue "▶ $*"; }

case "$PROBE" in
  empty-save)
    LAUNCH_ARG="--kc-runtime-empty-save-check"
    RESULT_FILE="kc_runtime_acceptance_empty_save.json"
    ;;
  layout-safe-area)
    LAUNCH_ARG="--kc-runtime-layout-check"
    RESULT_FILE="kc_runtime_acceptance_layout.json"
    ;;
  *)
    red "错误：未知验收探针 '$PROBE'，可选：empty-save / layout-safe-area"
    exit 8
    ;;
esac

case "$WAIT_SECONDS" in
  ''|*[!0-9]*)
    red "错误：WAIT_SECONDS 必须是正整数，当前值：$WAIT_SECONDS"
    exit 8
    ;;
esac
if [ "$WAIT_SECONDS" -le 0 ]; then
  red "错误：WAIT_SECONDS 必须大于 0，当前值：$WAIT_SECONDS"
  exit 8
fi

step "清理 ._*/.!* 临时文件"
find "$PROJECT_ROOT" -type f \( -name '._*' -o -name '.!*' \) -delete 2>/dev/null || true

UDID="$(xcrun simctl list devices available -j \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(next((t['udid'] for rt in d['devices'].values() for t in rt if t.get('name')=='$DEVICE_NAME'), ''))")"
if [ -z "$UDID" ]; then
  red "错误：找不到可用模拟器 '$DEVICE_NAME'。"
  exit 2
fi
green "设备: $DEVICE_NAME ($UDID)"

step "启动模拟器"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null 2>&1 || true

step "构建 $SCHEME ($CONFIGURATION)"
if ! xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
      -configuration "$CONFIGURATION" \
      -derivedDataPath "$DERIVED_DATA" \
      build >/tmp/kc_acceptance_build.log 2>&1; then
  red "构建失败，完整日志见 /tmp/kc_acceptance_build.log，末尾 20 行："
  tail -20 /tmp/kc_acceptance_build.log
  exit 3
fi
green "构建成功"

APP="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphonesimulator/KidCanvas.app"
if [ ! -d "$APP" ]; then
  red "找不到产物 .app: $APP"
  exit 4
fi

step "安装到 $DEVICE_NAME"
xcrun simctl install "$UDID" "$APP"

DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null || true)"
if [ -n "$DATA_CONTAINER" ]; then
  rm -f "$DATA_CONTAINER/Documents/$RESULT_FILE"
fi

step "启动 Debug 运行时验收探针：$PROBE"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
if ! xcrun simctl launch "$UDID" "$BUNDLE_ID" "$LAUNCH_ARG" >/tmp/kc_acceptance_launch.log 2>&1; then
  red "启动失败，完整日志见 /tmp/kc_acceptance_launch.log："
  cat /tmp/kc_acceptance_launch.log
  exit 5
fi

step "等待验收结果 JSON"
RESULT_PATH=""
for _ in $(seq 1 "$WAIT_SECONDS"); do
  DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null || true)"
  if [ -n "$DATA_CONTAINER" ] && [ -f "$DATA_CONTAINER/Documents/$RESULT_FILE" ]; then
    RESULT_PATH="$DATA_CONTAINER/Documents/$RESULT_FILE"
    break
  fi
  sleep 1
done

if [ -z "$RESULT_PATH" ]; then
  red "未在 ${WAIT_SECONDS}s 内生成验收结果：$RESULT_FILE"
  exit 6
fi

python3 - "$RESULT_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    result = json.load(handle)

print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
if not result.get("passed"):
    sys.exit(7)
PY

green "✓ 运行时交互验收通过 ($DEVICE_NAME)"
