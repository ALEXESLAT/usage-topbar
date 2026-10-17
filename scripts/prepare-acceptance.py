#!/usr/bin/env python3
"""Prepare isolated offline inputs. Does not launch an app or read user data."""
import json,os,time,uuid
from pathlib import Path
identifier=str(uuid.uuid4()).upper()
root=Path('/private/tmp')/('UsageTopbar-Acceptance-'+identifier)
root.mkdir(mode=0o700)
(root/'acceptance-marker').write_text(identifier+'\n')
now=time.time();points=[]
for i in range(577):
 if 490<=i<=504:continue
 t=now-12*86400+i*1800
 reading=dict(account='offline-acceptance-fixture',series='codex/secondary/10080.0',time=t,remaining=max(0,100-(i%240)*.35),resetsAt=t+604800,duration=604800,cards=[],availableCards=0)
 points.append(dict(reading=reading,gapBefore=i==505,event=None))
(root/'history-v1.json').write_text(json.dumps(dict(version=1,points=points)))
for f in root.iterdir():os.chmod(f,0o600)
print(root)
