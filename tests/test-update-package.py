#!/usr/bin/env python3
"""Metadata pre-signing gate only. No cryptographic signing or keychain access."""
from pathlib import Path
import importlib.util,plistlib,tempfile,zipfile,sys
sys.dont_write_bytecode = True
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('gate',root/'scripts/sign-update.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
info=plistlib.loads((root/'app/Info.plist').read_bytes());info['SUPublicEDKey']=(root/'app/update-public-key.txt').read_text().strip()
with tempfile.TemporaryDirectory(prefix='usage-topbar-package-tests-') as tmp:
 version=info['CFBundleShortVersionString'];build=info['CFBundleVersion']
 p=Path(tmp)/f'UsageTopbar-{version}-macOS-arm64.zip'
 def write(value):
  with zipfile.ZipFile(p,'w') as z:
   z.writestr('UsageTopbar.app/Contents/Info.plist',plistlib.dumps(value))
   z.writestr('UsageTopbar.app/Contents/Frameworks/Sparkle.framework/Versions/B/Resources/Info.plist',plistlib.dumps({'UsageTopbarStrictUpdateValidationRevision':1}))
 write(info);assert gate.validate(p,version,build)['preflight']=='passed'
 for field,value in [('UsageTopbarStrictUpdateValidation',False),('UsageTopbarHistorySource','simulation-switchable'),('UsageTopbarHistorySource',None),('CFBundleIdentifier','wrong.app'),('CFBundleVersion','20'),('CFBundleVersion',str(int(build)+1)),('CFBundleShortVersionString','9.0'),('SUPublicEDKey','invalid'),('SURequireSignedFeed',False),('SUAutomaticallyUpdate',True),('SUShowReleaseNotes',False)]:
  bad=dict(info)
  if value is None: bad.pop(field,None)
  else: bad[field]=value
  write(bad)
  try:gate.validate(p,version,build)
  except ValueError:pass
  else:raise AssertionError('Accepted mismatch '+field)

 # A valid app plist must not hide a missing or unpatched embedded updater.
 for revision in [None,0]:
  write(info)
  with zipfile.ZipFile(p,'w') as z:
   z.writestr('UsageTopbar.app/Contents/Info.plist',plistlib.dumps(info))
   marker={} if revision is None else {'UsageTopbarStrictUpdateValidationRevision':revision}
   z.writestr('UsageTopbar.app/Contents/Frameworks/Sparkle.framework/Versions/B/Resources/Info.plist',plistlib.dumps(marker))
  try:gate.validate(p,version,build)
  except ValueError:pass
  else:raise AssertionError('Accepted unpatched updater')

print('PASS pre-sign package identity, exact expected version/build, key and security flags; no cryptographic claim')
