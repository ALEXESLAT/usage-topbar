#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-recovery-tests-') as tmp:
 p=Path(tmp);(p/'main.swift').write_text((root/'tests/RecoveryTests.swift').read_text())
 subprocess.run(['xcrun','swiftc',*[str(root/'src'/f) for f in ['QuotaHistory.swift','ProgressGradient.swift','HistoryChart.swift']],str(p/'main.swift'),'-o',str(p/'tests'),'-module-cache-path',str(p/'cache'),'-framework','AppKit'],check=True)
 subprocess.run([str(p/'tests'),str(p)],check=True,timeout=30)
