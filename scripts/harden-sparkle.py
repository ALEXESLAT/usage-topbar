#!/usr/bin/env python3
"""Build a pinned, additive Sparkle validator patch. Never uses private keys."""
from pathlib import Path
import hashlib,json,os,plistlib,shutil,subprocess,sys,tempfile,fcntl
sdk,cache=map(lambda x:Path(x).resolve(),sys.argv[1:])
root=Path(__file__).resolve().parents[1]
patch=root/'vendor/sparkle/strict-update-validation.patch'
commit='eef1a539a373c1f1a320624b1130fc5de7b2e100'
source_hash='fd2a5de329be3619111f9a73a1adeac9725a92292f0431c93679e5e2b0d48a04'
compiler=subprocess.check_output(['xcodebuild','-version'])
identity=hashlib.sha256(patch.read_bytes()+compiler+source_hash.encode()+Path(__file__).read_bytes()).hexdigest()[:20]
dest=cache/('Sparkle-2.10.0-usage-'+identity)
def run(*args,**kwargs):return subprocess.run(list(map(str,args)),check=True,**kwargs)
def verify():
 info=plistlib.loads((dest/'Sparkle.framework/Resources/Info.plist').read_bytes())
 if info.get('UsageTopbarStrictUpdateValidationRevision')!=1:raise RuntimeError('Missing strict validator build marker')
 run('codesign','--verify','--deep','--strict',dest/'Sparkle.framework')
lock=(cache/'usage-sparkle-build.lock').open('a')
fcntl.flock(lock,fcntl.LOCK_EX)
if not dest.exists():
 archive=cache/('Sparkle-source-'+commit+'.tar.gz')
 if not archive.exists():
  download=archive.with_suffix('.download')
  run('curl','--fail','--location','--proto','=https','--proto-redir','=https','--tlsv1.2','https://codeload.github.com/sparkle-project/Sparkle/tar.gz/'+commit,'-o',download)
  if hashlib.sha256(download.read_bytes()).hexdigest()!=source_hash:raise RuntimeError('Sparkle source checksum mismatch')
  download.rename(archive)
 if hashlib.sha256(archive.read_bytes()).hexdigest()!=source_hash:raise RuntimeError('Sparkle source checksum mismatch')
 with tempfile.TemporaryDirectory(prefix='usage-sparkle-',dir=cache) as temporary:
  work=Path(temporary);source=work/'source';source.mkdir()
  run('tar','-xzf',archive,'--strip-components=1','-C',source)
  run('git','apply','--check',patch,cwd=source)
  run('git','apply',patch,cwd=source)
  build=work/'build';log=cache/('usage-sparkle-'+identity+'.log')
  with log.open('w') as output:
   try:run('xcodebuild','-project','Sparkle.xcodeproj','-scheme','Sparkle','-configuration','Release','-derivedDataPath',build,'ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','CODE_SIGNING_ALLOWED=NO','CODE_SIGNING_REQUIRED=NO','build',cwd=source,stdout=output,stderr=subprocess.STDOUT)
   except subprocess.CalledProcessError:
    print('Sparkle build failed; log: '+str(log),file=sys.stderr);raise
  stage=work/'sdk';run('ditto',sdk,stage)
  shutil.rmtree(stage/'Sparkle.framework')
  framework=stage/'Sparkle.framework';run('ditto',build/'Build/Products/Release/Sparkle.framework',framework)
  infofile=framework/'Resources/Info.plist';info=plistlib.loads(infofile.read_bytes());info['UsageTopbarStrictUpdateValidationRevision']=1;infofile.write_bytes(plistlib.dumps(info))
  for child in ['XPCServices/Downloader.xpc','XPCServices/Installer.xpc','Autoupdate','Updater.app']:
   run('codesign','--force','--sign','-',framework/'Versions/B'/child,stdout=sys.stderr)
  run('codesign','--force','--sign','-',framework,stdout=sys.stderr)
  run('codesign','--verify','--deep','--strict',framework)
  (stage/'usage-hardening.json').write_text(json.dumps(dict(commit=commit,source_sha256=source_hash,patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),revision=1)))
  stage.rename(dest)
verify()
print(dest)
