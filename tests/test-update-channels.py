#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('gate',root/'scripts/verify-update-release.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
def item(status,channel):
    node=ET.Element('item')
    for key,value in [('releaseStatus',status),('channel',channel)]:
        if value is not None: ET.SubElement(node,gate.SPARKLE+key).text=value
    return node
def rejects(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('accepted invalid publication metadata')
gate.validate_channel(item('published',None),'1.2.3')
gate.validate_channel(item('prerelease','beta'),'1.2.3-beta.10')
for version,status,channel in [('1.2.3','draft',None),('1.2.3',None,None),('1.2.3','prerelease',None),('1.2.3-beta.1','published',None),('1.2.3-beta.01','prerelease','beta'),('1.2','published',None),('1.2.3','published','beta')]:
    rejects(lambda:gate.validate_channel(item(status,channel),version))
for version,pre in [('1.2.3',False),('1.2.3-beta.10',True)]:
    record=dict(draft=False,prerelease=pre,tag_name='v'+version)
    gate.validate_github_release(record,version)
    rejects(lambda:gate.validate_github_release(dict(record,draft=True),version))
    rejects(lambda:gate.validate_github_release(dict(record,prerelease=not pre),version))
    rejects(lambda:gate.validate_github_release(dict(record,tag_name='v0.0.1'),version))
print('PASS signed channel metadata, SemVer, public release draft/prerelease/tag checks (synthetic only)')
