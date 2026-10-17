#!/usr/bin/env python3
"""Bind reviewed release notes to one feed item. Output is UNSIGNED; re-sign before use."""
import argparse,re,xml.etree.ElementTree as ET
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('feed',type=Path);p.add_argument('notes',type=Path);p.add_argument('--version',required=True);p.add_argument('--build',required=True)
a=p.parse_args();ns='http://www.andymatuschak.org/xml-namespaces/sparkle';ET.register_namespace('sparkle',ns)
notes=a.notes.read_text().strip()
if not notes.startswith('# Usage Topbar '+a.version+'\n'):p.error('Notes heading does not match the target version')
data=re.sub(r'<!-- sparkle-signatures:.*?-->\s*$','',a.feed.read_text(),flags=re.S)
root=ET.fromstring(data);items=[i for i in root.findall('./channel/item') if i.findtext('{'+ns+'}version')==a.build]
if len(items)!=1 or items[0].findtext('{'+ns+'}shortVersionString')!=a.version:p.error('Feed target does not match version/build')
item=items[0]
for old in item.findall('description'):item.remove(old)
node=ET.SubElement(item,'description',{'{'+ns+'}descriptionFormat':'plain-text'});node.text=notes
ET.ElementTree(root).write(a.feed,encoding='utf-8',xml_declaration=True)
print('Unsigned version-bound notes written; sign and verify this feed before upload.')
