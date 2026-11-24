#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_derived="${TMPDIR:-/tmp}/autoid-simulator-derived"
task_devices=$(mktemp "${TMPDIR:-/tmp}/autoid-devices.XXXXXX")
trap 'rm -f "$task_devices"' EXIT
if ! xcrun simctl list devices available -j > "$task_devices"; then
    echo '无法连接 CoreSimulator。请在 macOS 普通终端运行此脚本，并确认 Xcode 已安装 iOS Simulator runtime。' >&2
    exit 1
fi
task_device=$(python3 - "$task_devices" <<'PY'
import json, sys
with open(sys.argv[1]) as file:
    groups = json.load(file)['devices']
phones = [device for runtime in sorted(groups, reverse=True)
          for device in groups[runtime]
          if 'iPhone' in device['name'] and device.get('isAvailable', False)]
if not phones:
    sys.exit('未找到可用的 iPhone 模拟器，请在 Xcode 的 Platforms/Components 中安装 iOS runtime 并创建模拟器。')
device = next((item for item in phones if item['state'] == 'Booted'), phones[0])
print(device['udid'])
PY
)
task_state=$(xcrun simctl list devices booted -j)
if ! printf '%s' "$task_state" | python3 -c 'import json,sys; device=sys.argv[1]; data=json.load(sys.stdin); sys.exit(0 if any(d["udid"] == device for group in data["devices"].values() for d in group) else 1)' "$task_device"; then
    xcrun simctl boot "$task_device"
fi
open -a Simulator
xcrun simctl bootstatus "$task_device" -b
xcodebuild -project AutoIDPhoto.xcodeproj -scheme AutoIDPhoto \
    -configuration Debug -sdk iphonesimulator \
    -destination "id=$task_device" -derivedDataPath "$task_derived" \
    CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "$task_device" "$task_derived/Build/Products/Debug-iphonesimulator/AutoIDPhoto.app"
xcrun simctl launch "$task_device" com.jialishen.AutoIDPhoto
printf '\n应用已启动。模拟器不支持真实相机拍照，请通过相册测试；可把测试照片拖入模拟器后选择。\n'
