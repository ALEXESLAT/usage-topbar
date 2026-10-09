#!/usr/bin/env python3
"""Inject an approved PUBLIC key only; never generate or load a private key."""
import base64, os, plistlib, sys
from pathlib import Path
p = Path(sys.argv[1])
info = plistlib.loads(p.read_bytes())
key_file = os.environ.get('USAGE_TOPBAR_UPDATE_PUBLIC_KEY_FILE')
if key_file is None:
    bundled = Path(__file__).resolve().parents[1] / 'app/update-public-key.txt'
    if bundled.exists():
        key_file = str(bundled)
if key_file:
    key = Path(key_file).read_text().strip()
    try:
        data = base64.b64decode(key, validate=True)
        assert len(data) == 32 and any(data)
    except Exception:
        raise SystemExit('Invalid public verification key; expected base64-encoded 32 bytes.')
    info['SUPublicEDKey'] = key
if os.environ.get('USAGE_TOPBAR_REQUIRE_UPDATER') == '1' and 'SUPublicEDKey' not in info:
    raise SystemExit('Release blocked: approved update verification public key is missing.')
p.write_bytes(plistlib.dumps(info, sort_keys=False))
