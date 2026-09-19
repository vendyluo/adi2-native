#!/bin/bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo '需要管理員權限'; exit 1; }
dst='/Library/Audio/Plug-Ins/HAL/ADI2Native.driver'
if [[ -e "$dst" ]]; then
 [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$dst/Contents/Info.plist")" == 'local.ADI2Native.Driver' ]]
 /bin/rm -rf "$dst"
fi
if [[ -e /Library/Audio/Plug-Ins/HAL/ADI2Native.previous ]]; then
 [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' /Library/Audio/Plug-Ins/HAL/ADI2Native.previous/Contents/Info.plist)" == 'local.ADI2Native.Driver' ]]
 /bin/rm -rf /Library/Audio/Plug-Ins/HAL/ADI2Native.previous
fi
/usr/bin/killall coreaudiod || true
