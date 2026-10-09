#!/usr/bin/env python3
import json,sys,time,os
mode=os.path.basename(sys.argv[0])
if mode=='hang':
 time.sleep(10);sys.exit()
if mode=='oversized':
 sys.stdout.write('x'*1100000);sys.stdout.flush();time.sleep(10);sys.exit()
for line in sys.stdin:
 req=json.loads(line)
 if req.get('method')=='initialize':
  print(json.dumps({'id':1,'result':{}}),flush=True)
 elif req.get('method')=='account/rateLimits/read':
  if mode=='stall': continue
  if mode=='error':
   print(json.dumps({'id':req['id'],'error':{'code':-1,'message':'synthetic failure'}}),flush=True);continue
  limits={'primary':{'usedPercent':40,'windowDurationMins':300,'resetsAt':2000000000}}
  if mode=='foreign':
   result={'rateLimitsByLimitId':{'other-model':limits}}
  else: result={'rateLimits':limits}
  # An out-of-order response must not cancel or satisfy the real read.
  print(json.dumps({'id':-42,'result':{'rateLimits':{'primary':{'usedPercent':0}}}}),flush=True)
  print(json.dumps({'id':req['id'],'result':result}),flush=True)
  if mode=='recover':
   sys.stdout.write('{"partial":');sys.stdout.flush();time.sleep(.2);sys.exit()
