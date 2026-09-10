#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .build/icon-tools assets
swiftc -module-cache-path "$PWD/.build/module-cache" Sources/MacDuo/BrandIcon.swift scripts/generate-icon.swift -o .build/icon-tools/generate-icon
.build/icon-tools/generate-icon "$PWD/assets"
# ICNS PNG representations, including Retina sizes.
python3 - <<'PYICON'
from pathlib import Path
import struct
root = Path('assets')
representations = [('icp4', '16x16'), ('ic11', '16x16@2x'),
    ('icp5', '32x32'), ('ic12', '32x32@2x'), ('ic07', '128x128'),
    ('ic13', '128x128@2x'), ('ic08', '256x256'), ('ic14', '256x256@2x'),
    ('ic09', '512x512'), ('ic10', '512x512@2x')]
chunks = []
for kind, name in representations:
    data = (root / 'MacDuo.iconset' / f'icon_{name}.png').read_bytes()
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
(root / 'MacDuo.icns').write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PYICON
