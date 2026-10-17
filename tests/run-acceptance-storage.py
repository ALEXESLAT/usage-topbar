from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-acceptance-storage-') as d:
 p=Path(d);(p/'main.swift').write_text((r/'tests/AcceptanceStorageTests.swift').read_text())
 subprocess.run(['xcrun','swiftc',str(r/'src/ProgressGradient.swift'),str(r/'src/OverlayPreferences.swift'),str(p/'main.swift'),'-module-cache-path',str(p/'cache'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test'),str(p)],check=True)
