#!/usr/bin/env python3
"""Final ZIP/feed gate, before upload and again with downloaded files.
Only a public key is used. No network, publication or credential access.
"""
import argparse, hashlib, importlib.util, json, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
SPARKLE='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
spec=importlib.util.spec_from_file_location('release_guard',ROOT/'scripts/sign-update.py')
guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard)

def inspect(archive,feed,version,build):
    metadata=guard.validate(archive,version,build)
    data=feed.read_bytes()
    trailer=re.search(rb'<!-- sparkle-signatures:\s*edSignature: ([A-Za-z0-9+/=]+)\s*length: ([0-9]+)\s*-->\s*$',data)
    if not trailer or int(trailer[2]) != trailer.start(): raise ValueError('Missing or inconsistent signed-feed trailer')
    root=ET.fromstring(data)
    items=[i for i in root.findall('./channel/item') if i.findtext(SPARKLE+'version')==build]
    if len(items)!=1: raise ValueError('Expected exactly one matching feed build')
    item=items[0];enclosure=item.find('enclosure')
    if enclosure is None or item.findtext(SPARKLE+'shortVersionString')!=version: raise ValueError('Feed/package version mismatch')
    expected='https://github.com/ALEXESLAT/usage-topbar/releases/download/v'+version+'/'+archive.name
    if enclosure.get('url')!=expected or enclosure.get('length')!=str(metadata['length']): raise ValueError('Feed URL/length does not bind this archive')
    signature=enclosure.get(SPARKLE+'edSignature')
    if not signature: raise ValueError('Missing archive signature')
    return metadata,data[:trailer.start()],trailer[1].decode('ascii'),signature,hashlib.sha256(data).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('archive',type=Path);p.add_argument('feed',type=Path)
    p.add_argument('--version',required=True);p.add_argument('--build',required=True)
    p.add_argument('--expected-sha256',help='Required known ZIP hash when checking a public download')
    p.add_argument('--expected-feed-sha256',help='Known signed-feed hash before upload')
    a=p.parse_args()
    try:
        # Freeze both inputs before metadata and cryptographic verification.
        with tempfile.TemporaryDirectory(prefix='usage-topbar-verify-') as tmp:
            work=Path(tmp);archive=work/a.archive.name;feed=work/'appcast.xml'
            archive.write_bytes(a.archive.read_bytes());feed.write_bytes(a.feed.read_bytes())
            metadata,payload,feed_sig,zip_sig,feed_hash=inspect(archive,feed,a.version,a.build)
            if a.expected_sha256 and metadata['sha256']!=a.expected_sha256: raise ValueError('Downloaded ZIP differs from approved artifact')
            if a.expected_feed_sha256 and feed_hash!=a.expected_feed_sha256: raise ValueError('Downloaded feed differs from approved artifact')
            (work/'feed-payload').write_bytes(payload)
            verify=work/'verify'
            subprocess.run(['xcrun','swiftc',str(ROOT/'scripts/verify-ed25519.swift'),'-module-cache-path',str(work/'cache'),'-o',str(verify)],check=True)
            for file,signature in [(archive,zip_sig),(work/'feed-payload',feed_sig)]:
                subprocess.run([str(verify),str(ROOT/'app/update-public-key.txt'),str(file),signature],check=True)
            if hashlib.sha256(a.archive.read_bytes()).hexdigest()!=metadata['sha256'] or hashlib.sha256(a.feed.read_bytes()).hexdigest()!=feed_hash:
                raise ValueError('Input changed during final verification')
            print(json.dumps(dict(metadata,feed_sha256=feed_hash,archive_signature_verified=True,feed_signature_verified=True)))
    except (ValueError,KeyError,OSError,ET.ParseError,subprocess.CalledProcessError) as e: p.exit(2,str(e)+'\n')
if __name__=='__main__':main()
