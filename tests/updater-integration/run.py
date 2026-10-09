#!/usr/bin/env python3
"""Explicitly authorized local signing/integration test; never creates or exports keys.
Requires --allow-keychain-signing, an approved account and a disposable work dir.
No production URL policy override is compiled into the shipped app.
"""
import argparse, functools, hashlib, http.server, json, os, plistlib, re, shutil, subprocess, threading, time
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--work',required=True); parser.add_argument('--sparkle',required=True)
parser.add_argument('--allow-keychain-signing',action='store_true')
parser.add_argument('--cases',default='success,no-update,bad-feed,bad-archive,wrong-identity,wrong-version,cancel-check,cancel-offer,cancel-download,cancel-install,network-error,download-error')
a=parser.parse_args()
if not a.allow_keychain_signing: parser.error('Explicit signing authorization is required')
root=Path(__file__).resolve().parents[2];work=Path(a.work).resolve();sdk=Path(a.sparkle).resolve()
work.mkdir(parents=True,exist_ok=True)
key=(root/'app/update-public-key.txt').read_text().strip()
account='ALEXESLAT.usage-topbar'
def run(*args):
    result=subprocess.run(list(map(str,args)),capture_output=True,text=True,timeout=120)
    if result.returncode: raise RuntimeError(result.stderr or 'Tool failed')
    return result.stdout
class Server(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if '/download-interrupted/' in self.path and self.path.endswith('.zip'):
            self.send_response(200);self.send_header('Content-Length','99999999');self.end_headers();self.wfile.write(b'partial');self.close_connection=True;return
        return super().do_GET()
    def log_message(self,format,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Server,directory=str(work)))
threading.Thread(target=server.serve_forever,daemon=True).start();port=server.server_port
run('xcrun','clang','-fobjc-arc','-Werror','-Wno-incompatible-pointer-types','-target','arm64-apple-macos13.0','-framework','Cocoa','-F',sdk,'-framework','Sparkle','-Wl,-rpath,@executable_path/../Frameworks',root/'tests/updater-integration/Host.m','-o',work/'Host')
run('xcrun','swiftc',root/'src/OverlayPreferences.swift',root/'tests/updater-integration/PreferencesProbe.swift','-target','arm64-apple-macos13.0','-o',work/'PreferencesProbe')
results=[]
try:
 for case in a.cases.split(','):
    directory=work/case;directory.mkdir()
    log=directory/'events.log';bundle_id='local.alex.usage-topbar.fixture.'+case+'.'+str(time.time_ns())
    feed=f'http://127.0.0.1:{port}/{case}/appcast.xml'
    if case=='network-error':feed=f'http://127.0.0.1:{port}/{case}/missing.xml'
    def bundle(dest,version,identity=bundle_id):
        (dest/'Contents/MacOS').mkdir(parents=True)
        shutil.copy2(work/'Host',dest/'Contents/MacOS/Fixture')
        (dest/'Contents/Resources').mkdir()
        shutil.copy2(work/'PreferencesProbe',dest/'Contents/Resources/PreferencesProbe')
        run('codesign','--force','--sign','-',dest/'Contents/Resources/PreferencesProbe')
        run('ditto',sdk/'Sparkle.framework',dest/'Contents/Frameworks/Sparkle.framework')
        info=dict(CFBundleIdentifier=identity,CFBundleExecutable='Fixture',CFBundlePackageType='APPL',CFBundleName='UsageTopbar Update Fixture',CFBundleVersion=str(version),CFBundleShortVersionString='0.5.0',LSMinimumSystemVersion='13.0',LSUIElement=True,SUFeedURL=feed,SUPublicEDKey=key,SURequireSignedFeed=True,SUVerifyUpdateBeforeExtraction=True,SUSignedFeedFailureExpirationInterval=0,SUEnableAutomaticChecks=False,SUAutomaticallyUpdate=False,SUAllowsAutomaticUpdates=False,SUEnableSystemProfiling=False,SUShowReleaseNotes=False,SUEnableJavaScript=False,NSAppTransportSecurity={'NSAllowsLocalNetworking':True},FixtureScenario=case,FixtureLog=str(log))
        (dest/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        fw=dest/'Contents/Frameworks/Sparkle.framework'
        for child in ['XPCServices/Downloader.xpc','XPCServices/Installer.xpc','Autoupdate','Updater.app']:
            run('codesign','--force','--sign','-',fw/'Versions/B'/child)
        run('codesign','--force','--sign','-',fw)
        run('codesign','--force','--sign','-',dest)
    old=directory/'installed/UsageTopbarUpdateTest.app';bundle(old,21)
    new=directory/'candidate/UsageTopbarUpdateTest.app';newversion=21 if case=='no-update' else 20 if case=='wrong-version' else 23 if case=='mismatched-newer-version' else 22
    bundle(new,newversion,bundle_id+'.wrong' if case=='wrong-identity' else bundle_id)
    archive=directory/'UsageTopbar-0.5.0-macOS-arm64.zip'
    run('ditto','-c','-k','--keepParent',new,archive)
    signature=run(sdk/'bin/sign_update','--account',account,'-p',archive).strip()
    version='21' if case=='no-update' else '22'
    filename='missing.zip' if case=='download-error' else archive.name
    xml=f'''<?xml version="1.0" encoding="utf-8"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Local authorized fixture</title><item><title>Fixture</title><sparkle:version>{version}</sparkle:version><sparkle:shortVersionString>0.5.0</sparkle:shortVersionString><sparkle:minimumSystemVersion>13.0.0</sparkle:minimumSystemVersion><enclosure url="http://127.0.0.1:{port}/{case}/{filename}" sparkle:edSignature="{signature}" length="{archive.stat().st_size}" type="application/octet-stream" /></item></channel></rss>'''
    cast=directory/'appcast.xml';cast.write_text(xml)
    run(sdk/'bin/sign_update','--account',account,cast)
    run(sdk/'bin/sign_update','--account',account,'--verify',cast)
    if case=='bad-feed':cast.write_text(cast.read_text().replace('Local authorized fixture','Tampered unauthorized fixture'))
    if case=='bad-archive':
        data=bytearray(archive.read_bytes());data[len(data)//2]^=1;archive.write_bytes(data)
    if case=='missing-installer':
        helper=old/'Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate'
        shutil.move(str(helper),str(directory/'Autoupdate-preserved'))
        run('codesign','--force','--sign','-',old/'Contents/Frameworks/Sparkle.framework')
        run('codesign','--force','--sign','-',old)
    before=hashlib.sha256((old/'Contents/Info.plist').read_bytes()).hexdigest()
    with (directory/'stderr.log').open('w') as stderr:
        proc=subprocess.Popen([str(old/'Contents/MacOS/Fixture')],stdout=stderr,stderr=stderr)
        try:proc.wait(timeout=55)
        except subprocess.TimeoutExpired:proc.terminate();proc.wait(timeout=5)
    if log.exists() and 'installing\n' in log.read_text():
        deadline=time.time()+180
        while time.time()<deadline:
            events = log.read_text() if log.exists() else ''
            if events.count('termination-cleanup') >= 2: break
            time.sleep(.2)
    events=log.read_text() if log.exists() else ''
    after=plistlib.loads((old/'Contents/Info.plist').read_bytes())['CFBundleVersion'] if old.exists() else 'MISSING'
    children=re.findall(r'owned-child:(\d+)',events)
    child_alive=[]
    for pid in children:
        try:os.kill(int(pid),0);child_alive.append(pid)
        except ProcessLookupError:pass
    result=dict(case=case,exit=proc.returncode,installed_version=after,old_plist_unchanged=old.exists() and hashlib.sha256((old/'Contents/Info.plist').read_bytes()).hexdigest()==before,events=events,owned_children_still_alive=child_alive)
    expected_new = case == 'success' or case.startswith('preferences-')
    if case in ['wrong-identity','mismatched-newer-version']:
        result['expectation_met'] = after == '21' and result['old_plist_unchanged']
    elif expected_new:
        result['expectation_met'] = after == '22' and 'relaunched-new-version' in events and not child_alive
    else:
        result['expectation_met'] = after == '21' and result['old_plist_unchanged'] and 'timeout' not in events and not child_alive
    if case.startswith('preferences-'):
        result['preferences_preserved'] = 'preferences-preserved:21' in events and 'preferences-preserved:22' in events and 'preferences-failed' not in events
        result['expectation_met'] = result['expectation_met'] and result['preferences_preserved']
    results.append(result);(work/'results.json').write_text(json.dumps(results,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k!='events'}),flush=True)
finally:server.shutdown();server.server_close()
