#!/usr/bin/env python3
"""Compile the production declarations with synthetic-only regression fixtures."""
from pathlib import Path
import os,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
source=root/'src/UsageTopbar.swift'
if not source.exists(): source=root/'UsageTopbar.swift'
with tempfile.TemporaryDirectory(prefix='usage-topbar-tests-') as temp:
 work=Path(temp)
 declarations=(root/'src/OverlayPreferences.swift').read_text()+'\n'+(root/'src/AppUpdater.swift').read_text()+'\n'+source.read_text().split('if let index = CommandLine.arguments.firstIndex(of: "--render-preview")')[0]
 render_dir = Path(sys.argv[2]).resolve() if len(sys.argv)>2 and sys.argv[1]=='--render' else None
 test_source = 'RenderTests.swift' if render_dir else ('StartupTests.swift' if '--startup' in sys.argv else 'RegressionTests.swift')
 (work/'main.swift').write_text(declarations+'\n'+(root/'tests'/test_source).read_text())
 mock=(root/'tests/mock-server.py').read_text()
 for mode in ['recover','hang','stall','foreign','error','oversized']:
  p=work/mode;p.write_text(mock);p.chmod(0o755)
 subprocess.run(['xcrun','swiftc',str(work/'main.swift'),'-o',str(work/'tests'),'-target','arm64-apple-macos13.0','-module-cache-path',str(work/'cache'),'-framework','AppKit','-framework','CoreGraphics','-framework','IOKit','-framework','Network','-framework','ScreenCaptureKit'],check=True)
 if render_dir: render_dir.mkdir(parents=True,exist_ok=True)
 subprocess.run([str(work/'tests'),str(render_dir or work)],check=True,timeout=60)
