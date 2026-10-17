#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
output=Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='usage-chart-tests-') as tmp:
 p=Path(tmp);(p/'main.swift').write_text((root/'tests/ChartTests.swift').read_text())
 subprocess.run(['xcrun','swiftc','-DUSAGE_TOPBAR_TESTING',str(root/'src/QuotaHistory.swift'),str(root/'src/ProgressGradient.swift'),str(root/'src/HistoryChart.swift'),str(p/'main.swift'),'-o',str(p/'tests'),'-module-cache-path',str(p/'cache'),'-framework','AppKit'],check=True)
 subprocess.run([str(p/'tests'),str(output),str(p)],check=True,timeout=30)
