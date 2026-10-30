"""Scene geometry from normalized OSM facts; no invented course or tree locations.

Canopy symbols inside mapped woodland illustrate land cover, not surveyed trees.
"""
import math

RAD=math.pi/180
EARTH=6371008.8

def project(point,origin):
    return [(point[1]-origin[1])*RAD*EARTH*math.cos(origin[0]*RAD),(point[0]-origin[0])*RAD*EARTH]

def unproject(point,origin):
    return [origin[0]+point[1]/(RAD*EARTH),origin[1]+point[0]/(RAD*EARTH*math.cos(origin[0]*RAD))]

def inside(p,ring):
    yes=False
    for a,b in zip(ring,ring[1:]+ring[:1]):
        if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:yes=not yes
    return yes

def clip(ring,bounds):
    result=ring
    for axis,edge,lower in ((0,bounds[0],True),(0,bounds[2],False),(1,bounds[1],True),(1,bounds[3],False)):
        old=result;result=[]
        if not old:break
        previous=old[-1]
        for current in old:
            pi=previous[axis]>=edge if lower else previous[axis]<=edge
            ci=current[axis]>=edge if lower else current[axis]<=edge
            if ci!=pi:
                t=(edge-previous[axis])/(current[axis]-previous[axis])
                result.append([previous[0]+t*(current[0]-previous[0]),previous[1]+t*(current[1]-previous[1])])
            if ci:result.append(current)
            previous=current
    return result

def scene_for(course,hole):
    origin=hole['tee']; path=[project(p,origin) for p in hole['path']+hole['green']]
    # Bounded geographic coverage retained through zoom/pan; not an unbounded basemap.
    margin=100
    bounds=[min(p[0] for p in path)-margin,min(p[1] for p in path)-margin,max(p[0] for p in path)+margin,max(p[1] for p in path)+margin]
    surfaces=[]; actual=[]; woods=[]
    order={'grass':0,'rough':0,'forest':1,'water':2,'fairway':3,'tee':4,'bunker':5,'green':6}
    for f in course['mapFeatures']:
        points=[project(p,origin) for p in f['points']]
        if f['kind']=='tree':
            p=points[0]
            if bounds[0]<=p[0]<=bounds[2] and bounds[1]<=p[1]<=bounds[3]:actual.append(f['points'][0])
            continue
        clipped=clip(points,bounds)
        if len(clipped)<3:continue
        surfaces.append({'kind':f['kind'],'points':[unproject(p,origin) for p in clipped]})
        if f['kind']=='forest':woods.append(clipped)
    surfaces.sort(key=lambda f:order[f['kind']])
    symbols=[]
    # Uniform area sampling, bounded up front. Spacing grows rather than silently truncating a corner.
    spacing=max(9.0,math.sqrt((bounds[2]-bounds[0])*(bounds[3]-bounds[1])/550.0))
    y=bounds[1]+spacing/2
    row=0
    while y<bounds[3]:
        x=bounds[0]+spacing/2+(spacing/2 if row%2 else 0)
        while x<bounds[2]:
            if any(inside([x,y],w) for w in woods):symbols.append(unproject([x,y],origin))
            x+=spacing
        y+=spacing;row+=1
    return {'surfaces':surfaces,'trees':actual,'canopySymbols':symbols,'coverage':[unproject([bounds[0],bounds[1]],origin),unproject([bounds[2],bounds[3]],origin)]}
