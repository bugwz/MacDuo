#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
VERSION="${VERSION:-0.0.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS=(--arch arm64 --arch x86_64)
if [[ "${NATIVE_ONLY:-0}" == 1 ]]; then ARCHS=(); fi
swift build --disable-sandbox --cache-path "$PWD/.build/cache" -c release "${ARCHS[@]}"
BIN_DIR=$(swift build --disable-sandbox --cache-path "$PWD/.build/cache" -c release "${ARCHS[@]}" --show-bin-path)
APP="$PWD/dist/MacDuo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp assets/MacDuo.icns "$APP/Contents/Resources/MacDuo.icns"
cp "$BIN_DIR/MacDuo" "$APP/Contents/MacOS/MacDuo"
export VERSION BUILD_NUMBER APP
python3 - <<'PY'
import os, plistlib, re
from datetime import datetime, timezone
from pathlib import Path
version = os.environ['VERSION']
build = os.environ['BUILD_NUMBER']
if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not build.isdigit():
    raise SystemExit('VERSION must be X.Y.Z and BUILD_NUMBER must be numeric')
info = dict(CFBundleExecutable='MacDuo', CFBundleIdentifier='dev.macduo.app',
    CFBundleIconFile='MacDuo', CFBundleName='MacDuo', CFBundleDisplayName='MacDuo', CFBundlePackageType='APPL',
    CFBundleShortVersionString=version, CFBundleVersion=build,
    LSMinimumSystemVersion='14.0', NSHighResolutionCapable=True,
    CFBundleDevelopmentRegion='en', CFBundleLocalizations=['en', 'zh-Hans'],
    MacDuoBuildDate=datetime.now(timezone.utc).isoformat(),
    NSScreenCaptureUsageDescription='MacDuo uses your desktop for the folding effect. Frames stay in local memory; no audio, saving, or uploading.')
with (Path(os.environ['APP']) / 'Contents/Info.plist').open('wb') as f:
    plistlib.dump(info, f)
for language, description in {
    'en': 'MacDuo uses your desktop for the folding effect. Frames stay in local memory; no audio, saving, or uploading.',
    'zh-Hans': 'MacDuo 将当前桌面画面用于折叠效果。画面仅在本机内存中处理，不录音、不保存、不上传。',
}.items():
    folder = Path(os.environ['APP']) / 'Contents/Resources' / (language + '.lproj')
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'InfoPlist.strings').write_text('"NSScreenCaptureUsageDescription" = "' + description + '";\n', encoding='utf-8')
PY
# Persist the selected certificate hash in a gitignored file to prevent accidental
# identity changes between local builds. CI supplies its identity explicitly.
IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" && -f .local-signing-identity ]]; then
    IDENTITY=$(cat .local-signing-identity)
fi
if [[ -z "$IDENTITY" ]]; then
    if [[ "${REQUIRE_SIGNING:-0}" == 1 ]]; then
        print -u2 'Release requires CODE_SIGN_IDENTITY (Developer ID Application).'
        exit 1
    fi
    IDENTITY=-
    print -u2 '注意：临时签名会随代码变化，无法保证更新后保留授权。设置固定 CODE_SIGN_IDENTITY 后再安装和授权。'
fi
if [[ "${REQUIRE_SIGNING:-0}" == 1 && "$IDENTITY" == - ]]; then
    print -u2 'Ad hoc signing is forbidden for releases.'; exit 1
fi
SIGN_ARGS=(--force --sign "$IDENTITY")
if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then SIGN_ARGS+=(--keychain "$SIGNING_KEYCHAIN"); fi
if [[ "$IDENTITY" != - ]]; then
    SIGN_ARGS+=(--options runtime)
    if [[ "${REQUIRE_SIGNING:-0}" == 1 ]]; then SIGN_ARGS+=(--timestamp); fi
fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"
if [[ "${REQUIRE_SIGNING:-0}" == 1 ]]; then
    # Capture all output first: grep -q can close a pipe early, causing
    # codesign to exit with SIGPIPE under pipefail despite a valid signature.
    SIGNING_DETAILS=$(codesign -dvvv "$APP" 2>&1)
    /usr/bin/grep -q '^Authority=Developer ID Application:' <<< "$SIGNING_DETAILS" || {
        print -u2 'Release must use Developer ID Application, not Apple Development.'; exit 1
    }
fi
print "已生成：$APP"
