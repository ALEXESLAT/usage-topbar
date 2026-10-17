#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-history-tests-') as tmp:
 p=Path(tmp)
 (p/'main.swift').write_text((root/'tests/HistoryTests.swift').read_text())
 subprocess.run(['xcrun','swiftc',str(root/'src/QuotaHistory.swift'),str(p/'main.swift'),'-o',str(p/'tests'),'-module-cache-path',str(p/'cache')],check=True)
 subprocess.run([str(p/'tests'),str(p)],check=True,timeout=30)
