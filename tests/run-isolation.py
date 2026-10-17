#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-isolation-tests-') as tmp:
 p=Path(tmp);(p/'main.swift').write_text((root/'tests/IsolationTests.swift').read_text())
 for flags in [[],['-DUSAGE_TOPBAR_TESTING']]:
  subprocess.run(['xcrun','swiftc',*flags,str(root/'src/QuotaHistory.swift'),str(root/'src/AppUpdater.swift'),str(p/'main.swift'),'-module-cache-path',str(p/'cache'),'-o',str(p/'probe'),'-framework','AppKit'],check=True)
  subprocess.run([str(p/'probe'),str(root/'app/Info.plist')],check=True,timeout=10)
