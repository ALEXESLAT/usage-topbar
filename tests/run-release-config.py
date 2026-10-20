#!/usr/bin/env python3
"""Compile both product configurations; exercise real menu/editor construction offscreen."""
from pathlib import Path
import subprocess,tempfile,plistlib,uuid
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='usage-release-config-') as tmp:
 p=Path(tmp)
 sources=['QuotaHistory','HistoryChart','OverlayPreferences','ProgressGradient','GradientEditor','AppUpdater']
 declarations='\n'.join((root/f'src/{name}.swift').read_text() for name in sources)+'\n'+(root/'src/UsageTopbar.swift').read_text().split('if let index = CommandLine.arguments.firstIndex(of: "--render-preview")')[0]
 (p/'main.swift').write_text(declarations+'\n'+(root/'tests/ReleaseConfigurationTests.swift').read_text())
 # The UI entry method must remain a direct call; presentation itself is not invoked here.
 assert '@objc private func showGradientSettings() { gradientEditor.show() }' in declarations
 assert 'guard AppVariant.isTesting else { return }' not in (root/'src/GradientEditor.swift').read_text()
 for channel,flags in [('release',[]),('testing',['-DUSAGE_TOPBAR_TESTING'])]:
  app=p/(channel+'.app');binary=app/'Contents/MacOS/Probe';binary.parent.mkdir(parents=True)
  info=plistlib.loads((root/'app/Info.plist').read_bytes())
  fixture_version,fixture_build=('9.8.7','987') if channel=='release' else ('8.7.6','876')
  info.update(CFBundleShortVersionString=fixture_version,CFBundleVersion=fixture_build,CFBundleIdentifier='local.alex.usage.configtest.'+str(uuid.uuid4()),CFBundleExecutable='Probe')
  (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
  subprocess.run(['xcrun','swiftc',*flags,str(p/'main.swift'),'-o',str(binary),'-target','arm64-apple-macos13.0','-module-cache-path',str(p/'cache'),'-framework','AppKit','-framework','CoreGraphics','-framework','IOKit','-framework','Network','-framework','ScreenCaptureKit'],check=True)
  subprocess.run([str(binary),str(p),f'{fixture_version} ({fixture_build})'],check=True,timeout=45)
