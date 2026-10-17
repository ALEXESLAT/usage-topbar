#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-migration-tests-') as tmp:
 p=Path(tmp);(p/'main.swift').write_text((root/'tests/MigrationTests.swift').read_text())
 subprocess.run(['xcrun','swiftc',str(root/'src/QuotaHistory.swift'),str(p/'main.swift'),'-module-cache-path',str(p/'cache'),'-o',str(p/'tests')],check=True)
 args=[]
 if len(sys.argv)>1:
  snapshot=p/'source-snapshot.json';snapshot.write_bytes(Path(sys.argv[1]).read_bytes());args=[str(snapshot)]
 subprocess.run([str(p/'tests'),str(p),*args],check=True,timeout=30)
