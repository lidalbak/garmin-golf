#!/usr/bin/env python3
"""Download/normalize OSM source. No invented coordinates or repair of source tags."""
import argparse, collections, datetime, hashlib, json, math, pathlib, urllib.request, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parent.parent
CONFIG=[('bogstad','Oslo Golfklubb – Bogstad','10.62,59.96,10.64,59.975'),('baerum','Bærum Golfklubb','10.48,59.95,10.51,59.97')]
def inside(p,poly):
 y,x=p; yes=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  ay,ax=a;by,bx=b
  if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:yes=not yes
 return yes
def dist(a,b):return math.hypot((a[0]-b[0])*111195,(a[1]-b[1])*111195*math.cos(math.radians(a[0])))
def normalize(cid,name,bbox,download):
 f=ROOT/'data'/f'{cid}-raw.osm'; url='https://api.openstreetmap.org/api/0.6/map?bbox='+bbox
 if download:
  req=urllib.request.Request(url,headers={'User-Agent':'GolfAppVenu2-course-import/1.0'})
  with urllib.request.urlopen(req,timeout=45) as r: raw=r.read()
  ET.fromstring(raw)  # Never replace a source snapshot with an HTTP error document.
  f.write_bytes(raw)
  f.with_suffix('.metadata.json').write_text(json.dumps({'sourceUrl':url,'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sha256':hashlib.sha256(raw).hexdigest()},indent=2)+'\n')
 raw=f.read_bytes()
 metadata=json.loads(f.with_suffix('.metadata.json').read_text())
 if hashlib.sha256(raw).hexdigest()!=metadata['sha256']:raise ValueError('Raw snapshot differs from its acquisition metadata: '+str(f))
 root=ET.fromstring(raw);nodes={n.attrib['id']:[float(n.attrib['lat']),float(n.attrib['lon'])] for n in root.findall('node')}
 features=[]; map_features=[]
 for w in root.findall('way'):
  tags={t.attrib['k']:t.attrib['v'] for t in w.findall('tag')}; ids=[n.attrib['ref'] for n in w.findall('nd')]
  if not all(n in nodes for n in ids):continue
  points=[nodes[n] for n in ids]
  kind=None
  if tags.get('natural')=='water' or tags.get('golf') in ('water_hazard','lateral_water_hazard'):kind='water'
  elif tags.get('golf') in ('fairway','green','bunker','tee','rough'):kind=tags['golf']
  elif tags.get('natural') in ('wood','scrub') or tags.get('landuse')=='forest':kind='forest'
  elif tags.get('landuse') in ('grass','meadow'):kind='grass'
  if kind and len(points)>=4 and ids[0]==ids[-1]:
   map_features.append({'id':w.attrib['id'],'kind':kind,'points':points,'sourceUrl':'https://www.openstreetmap.org/way/'+w.attrib['id'],'sourceUpdatedAt':w.get('timestamp')})
  if not tags.get('golf'):continue
  features.append({'id':w.attrib['id'],'type':tags['golf'],'points':[nodes[n] for n in ids], 'timestamp':w.get('timestamp'),'tags':tags})
 for n in root.findall('node'):
  t={tag.get('k'):tag.get('v') for tag in n.findall('tag')}
  if t.get('natural')=='tree':map_features.append({'id':n.attrib['id'],'kind':'tree','points':[nodes[n.attrib['id']]],'sourceUrl':'https://www.openstreetmap.org/node/'+n.attrib['id'],'sourceUpdatedAt':n.get('timestamp')})
 greens=[f for f in features if f['type']=='green' and len(f['points'])>3 and f['points'][0]==f['points'][-1]]
 holes=[]
 for f in features:
  if f['type']!='hole':continue
  t=f['tags']; num=t.get('ref');p=f['points']
  if not num or not num.isdigit() or len(p)<2:continue
  matches=[g for g in greens if inside(p[-1],g['points'])]
  g=matches[0] if len(matches)==1 else None
  # Center retains the mapped hole endpoint; it is not asserted to be green center or current pin.
  h={'number':int(num),'par':int(t['par']) if t.get('par','').isdigit() else None,'strokeIndex':int(t['handicap']) if t.get('handicap','').isdigit() else None,'tee':p[0],'center':p[-1],'targetKind':'osm-hole-endpoint','green':g['points'] if g else [],'path':p,'hazards':[], 'sourceUrl':'https://www.openstreetmap.org/way/'+f['id'],'sourceUpdatedAt':f['timestamp'],'greenSourceUrl':'https://www.openstreetmap.org/way/'+g['id'] if g else None,'association':'endpoint-contained-by-one-green' if g else 'no-unique-containing-green'}
  # Nearby polygons shown as context; proximity does not prove official hole assignment.
  for feat in features:
   if feat['type'] not in ('bunker','water_hazard','lateral_water_hazard'):continue
   if min(dist(a,b) for a in p for b in feat['points'])<=100:
    h['hazards'].append({'type':feat['type'],'points':feat['points'],'sourceUrl':'https://www.openstreetmap.org/way/'+feat['id'],'association':'within-100m-of-path-vertex-context-only'})
  holes.append(h)
 
 for h in holes:
  assert h['par'] is None or 1 <= h['par'] <= 9, 'invalid par'
  assert h['strokeIndex'] is None or 1 <= h['strokeIndex'] <= 18, 'invalid index'
  for lat,lon in h['path']+h['green']:
   assert math.isfinite(lat) and math.isfinite(lon) and -90<=lat<=90 and -180<=lon<=180, 'invalid coordinate'
 holes.sort(key=lambda h:h['number']); assert [h['number'] for h in holes]==list(range(1,19)), 'incomplete or ambiguous course holes'
 counts=collections.Counter(h['strokeIndex'] for h in holes);dupes=[k for k,v in counts.items() if v>1]
 notes=['OSM snapshot, not field verified. Hole way starts and endpoints represent mapped play line, not selected tee markers or current pins. Green association uses endpoint containment. Nearby hazards are contextual, not complete or officially assigned.']
 if dupes:
  notes.append('Duplicate source stroke indices '+str(dupes)+'; affected values withheld for scoring and retained in sourceStrokeIndex.')
  for h in holes:
   if h['strokeIndex'] in dupes:h['sourceStrokeIndex']=h['strokeIndex'];h['strokeIndex']=None
 return {'id':cid,'name':name,'sourceUrl':url,'license':'ODbL-1.0','attribution':'© OpenStreetMap contributors','asOf':json.loads((ROOT/'data'/f'{cid}-raw.osm').with_suffix('.metadata.json').read_text())['retrievedAt'],'rawSha256':hashlib.sha256((ROOT/'data'/f'{cid}-raw.osm').read_bytes()).hexdigest(),'notes':notes,'holes':holes,'features':features,'mapFeatures':map_features,'mapCoverage':'Closed complete ways and mapped individual trees; multipolygon relations not rendered; forest canopy symbols are illustrative.'}
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--download',action='store_true');args=ap.parse_args()
 result={'schemaVersion':1,'courses':[normalize(*c,args.download) for c in CONFIG]}
 target=ROOT/'data'/'courses.json';target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print(target)
 for c in result['courses']:print(c['id'],len(c['holes']),'holes;',sum(bool(h['green']) for h in c['holes']),'matched greens;',sum(len(h['hazards']) for h in c['holes']),'context hazards')
