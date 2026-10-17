#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-gradient-tests-') as temp:
 p=Path(temp);(p/'main.swift').write_text((root/'tests/GradientTests.swift').read_text())
 subprocess.run(['xcrun','swiftc',str(root/'src/ProgressGradient.swift'),str(p/'main.swift'),'-module-cache-path',str(p/'cache'),'-o',str(p/'tests')],check=True)
 subprocess.run([str(p/'tests')],check=True,timeout=10)
