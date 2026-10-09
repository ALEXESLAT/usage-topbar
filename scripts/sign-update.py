#!/usr/bin/env python3
"""Project release guard. Default is read-only; --sign uses the approved Keychain key.
Never generates, exports or accepts a private key. No upload/publish operations.
"""
import argparse, base64, json, plistlib, subprocess, zipfile
from pathlib import Path, PurePosixPath
ROOT=Path(__file__).resolve().parents[1]
ACCOUNT='ALEXESLAT.usage-topbar'

def validate(archive, version, build):
    if not build.isdecimal() or str(int(build)) != build or int(build)<1:
        raise ValueError('Expected a positive integer build')
    if archive.name != f'UsageTopbar-{version}-macOS-arm64.zip':
        raise ValueError('Archive filename does not match the expected version')
    with zipfile.ZipFile(archive) as z:
        names=z.namelist()
        if len(names)!=len(set(names)) or any(PurePosixPath(n).is_absolute() or '..' in PurePosixPath(n).parts or not n.startswith('UsageTopbar.app/') for n in names):
            raise ValueError('Unexpected archive layout or duplicate entries')
        info=plistlib.loads(z.read('UsageTopbar.app/Contents/Info.plist'))
    expected={'CFBundleIdentifier':'local.alex.usage-topbar.https-test','CFBundleExecutable':'UsageTopbar','CFBundleVersion':build,'CFBundleShortVersionString':version,'SUFeedURL':'https://raw.githubusercontent.com/ALEXESLAT/usage-topbar/updater-https-validation/updates/appcast.xml','SUPublicEDKey':(ROOT/'app/update-public-key.txt').read_text().strip(),'SURequireSignedFeed':True,'SUVerifyUpdateBeforeExtraction':True,'SUSignedFeedFailureExpirationInterval':0,'SUEnableAutomaticChecks':False,'SUAutomaticallyUpdate':False,'SUAllowsAutomaticUpdates':False,'SUEnableSystemProfiling':False,'SUEnableJavaScript':False}
    for key,value in expected.items():
        if info.get(key)!=value:raise ValueError('Package metadata mismatch: '+key)
    if len(base64.b64decode(expected['SUPublicEDKey'],validate=True))!=32:
        raise ValueError('Invalid repository public key')
    return {'version':version,'build':build,'bundle_id':info['CFBundleIdentifier'],'preflight':'passed'}

def main():
    p=argparse.ArgumentParser();p.add_argument('archive',type=Path);p.add_argument('--version',required=True);p.add_argument('--build',required=True);p.add_argument('--sign',action='store_true');a=p.parse_args()
    try: result=validate(a.archive,a.version,a.build)
    except (ValueError,KeyError,zipfile.BadZipFile,plistlib.InvalidFileException) as e:p.exit(2,str(e)+'\n')
    print(json.dumps(result),flush=True)
    if a.sign:
        sdk=Path(subprocess.check_output([str(ROOT/'scripts/fetch-sparkle.sh')],text=True).strip())
        subprocess.run([str(sdk/'bin/sign_update'),'--account',ACCOUNT,str(a.archive.resolve())],check=True)
if __name__=='__main__':main()
