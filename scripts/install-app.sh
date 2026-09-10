#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
SOURCE="$PWD/dist/MacDuo.app"
DESTINATION=/Applications/MacDuo.app
if [[ ! -d "$SOURCE" ]]; then
    print -u2 '缺少应用包，请先运行 scripts/build-app.sh。'; exit 1
fi
codesign --verify --strict "$SOURCE"
# Do not re-sign during installation: preserve precisely the built identity.
if [[ -e "$DESTINATION" ]]; then
    print -u2 '已有安装版本。请先退出 MacDuo，并通过 Finder 用 dist/MacDuo.app 替换 /Applications/MacDuo.app。'
    exit 1
fi
ditto "$SOURCE" "$DESTINATION"
codesign --verify --strict "$DESTINATION"
print '已安装到 /Applications/MacDuo.app。请退出旧进程，再从应用程序文件夹打开。'
