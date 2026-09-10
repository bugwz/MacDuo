#!/bin/zsh
set -euo pipefail
# Launching must never rebuild/re-sign the application or select a dist copy.
APP=/Applications/MacDuo.app
if [[ ! -d "$APP" ]]; then
    print -u2 '尚未安装。先运行 scripts/install-app.sh，再运行此脚本。'
    exit 1
fi
open "$APP"
