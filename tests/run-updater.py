#!/usr/bin/env python3
"""No keys or live feeds. Compile policy/controller tests against pinned Sparkle."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
sparkle=subprocess.check_output([str(root/'scripts/fetch-sparkle.sh')],text=True).strip()
with tempfile.TemporaryDirectory(prefix='usage-topbar-updater-tests-') as temp:
    work=Path(temp)
    (work/'main.swift').write_text((root/'src/AppUpdater.swift').read_text()+'\n'+(root/'tests/UpdaterTests.swift').read_text())
    exe=work/'tests'
    subprocess.run(['xcrun','swiftc',str(work/'main.swift'),'-o',str(exe),'-target','arm64-apple-macos13.0','-module-cache-path',str(work/'cache'),'-framework','AppKit','-F',sparkle,'-framework','Sparkle','-Xlinker','-rpath','-Xlinker',sparkle],check=True)
    subprocess.run([str(exe),str(root/'app/Info.plist')],check=True,timeout=30)
