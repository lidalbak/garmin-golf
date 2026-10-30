#!/usr/bin/env python3
"""Documentation design preview, NOT a Garmin simulator screenshot.

Requires Pillow. Uses the same retained scene resources/palette as the app.
"""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from map_scene import project
from map_layout import LAYOUT, main_span

ROOT=Path(__file__).resolve().parents[1]
STYLE=json.loads((ROOT/'data/map-style.json').read_text())
SCALE=2

def font(size,number=False):
    path='/System/Library/Fonts/Supplemental/Arial Narrow.ttf' if number else '/System/Library/Fonts/Helvetica.ttc'
    return ImageFont.truetype(path,round(size*SCALE))

def text(image,x,y,value,size=24,color='#F1F3EA',number=False):
    d=ImageDraw.Draw(image);f=font(size,number)
    d.text((x*SCALE,y*SCALE),value,font=f,fill=color,anchor='mt')

def bearing(a,b):
    lat1,lat2=map(math.radians,(a[0],b[0])); dl=math.radians(b[1]-a[1])
    return math.atan2(math.sin(dl)*math.cos(lat2), math.cos(lat1)*math.sin(lat2)-math.sin(lat1)*math.cos(lat2)*math.cos(dl))

def make_map(hole,resource,w,h,green=False,zoom=1,fit=None):
    fx,fy,fw,fh=fit if fit is not None else (0,0,w,h)
    origin=hole['tee']; angle=bearing(origin,hole['center']);cs=math.cos(angle);sn=math.sin(angle)
    def local(p):
        e,n=project(p,origin);return [e*cs-n*sn,e*sn+n*cs]
    points=list(map(local,resource['green'] if green else resource['path']+resource['green']))
    xx=[p[0] for p in points];yy=[p[1] for p in points];pad=6 if green else 18
    scale=min(fw/(max(xx)-min(xx)+2*pad),fh/(max(yy)-min(yy)+2*pad))*zoom
    cx=(min(xx)+max(xx))/2;cy=(min(yy)+max(yy))/2
    def screen(p):
        x,y=local(p);return ((fx+fw/2+(x-cx)*scale)*SCALE,(fy+fh/2-(y-cy)*scale)*SCALE)
    img=Image.new('RGB',(w*SCALE,h*SCALE),'#'+STYLE['background']); d=ImageDraw.Draw(img)
    for surface in resource['scene']['surfaces']:
        d.polygon([screen(p) for p in surface['points']],fill='#'+STYLE[surface['kind']])
    for index,p in enumerate(resource['scene']['canopySymbols']+resource['scene']['trees']):
        x,y=screen(p);r=max(2,min(9,4.5*scale))*SCALE
        for dx,dy,rr,color in ((r*.4,r*.5,r,STYLE['treeShadow']),(0,0,r,STYLE['treeCanopy'][index%3]),(-r*.25,-r*.3,r*.6,STYLE['treeHighlight'][index%2])):
            d.ellipse((x+dx-rr,y+dy-rr,x+dx+rr,y+dy+rr),fill='#'+color)
    if not green:
        line=[screen(p) for p in resource['path']]
        d.line(line,fill='#D1DBAA',width=SCALE)
        # Reference layup dots are radial distance markers, not surveyed safe landing points.
        a=screen(origin);b=screen(hole['center']);dist=math.hypot(*project(hole['center'],origin))
        for meters,color in ((100,'#FF6250'),(150,'#F1F3EA'),(200,'#54A4FF'),(250,'#FFDE00')):
            if meters<dist:
                x=b[0]+(a[0]-b[0])*meters/dist;y=b[1]+(a[1]-b[1])*meters/dist;r=3*SCALE
                d.ellipse((x-r,y-r,x+r,y+r),fill=color)
    x,y=screen(hole['center']);d.line((x,y,x,y-22*SCALE),fill='#F1F3EA',width=2*SCALE)
    d.polygon([(x,y-22*SCALE),(x+13*SCALE,y-16*SCALE),(x,y-12*SCALE)],fill='#FF6250')
    return img

def face(hole,resource,mode):
    img=Image.new('RGB',(416*SCALE,416*SCALE),'black');d=ImageDraw.Draw(img)
    title=f'#{hole["number"]}  Par {hole["par"]}' if mode=='main' else 'Hullkart' if mode=='map' else 'Green · dra flagget'
    if mode=='main':
        x,y,w,h=LAYOUT['main']['viewport']; fx,fy,fw,fh=LAYOUT['main']['fit']
        tile=make_map(hole,resource,w,h,fit=(fx-x,fy-y,fw,fh))
        mask=Image.new('L',tile.size,0);md=ImageDraw.Draw(mask)
        for row in range(h*SCALE):
            left,right=main_span(y+row/SCALE)
            md.line(((left-x)*SCALE,row,(right-x)*SCALE,row),fill=255)
        img.paste(tile,(x*SCALE,y*SCALE),mask)
        # Design values are calculated at the mapped tee; they are not a GPS observation.
        direction=project(hole['center'],hole['tee']);length=math.hypot(*direction);hits=[]
        for a,b in zip(hole['green'],hole['green'][1:]):
            a=project(a,hole['tee']);b=project(b,hole['tee']);e=[b[0]-a[0],b[1]-a[1]]
            cross=direction[0]*e[1]-direction[1]*e[0]
            if abs(cross)<1e-6:continue
            t=(a[0]*e[1]-a[1]*e[0])/cross;u=(a[0]*direction[1]-a[1]*direction[0])/cross
            if t>=0 and 0<=u<=1:hits.append(t*length)
        text(img,112,98,str(round(max(hits))),56,number=True)
        text(img,112,167,str(round(length)),80,'#FFDE00',True)
        text(img,112,253,str(round(min(hits))),56,number=True)
        text(img,112,313,'meter',17,'#A6AD9F')
        text(img,118,350,'Kartlagt tee',17,'#A6AD9F')
    else:
        x,y,w,h=LAYOUT['detail']['viewport'];fx,fy,fw,fh=LAYOUT['detail']['fit']
        img.paste(make_map(hole,resource,w,h,green=mode=='green',zoom=1.5 if mode=='map' else 1,fit=(fx-x,fy-y,fw,fh)),(x*SCALE,y*SCALE))
        for x,w,label in ((77,64,'−'),(169,78,'1.5×' if mode=='map' else '1.0×'),(275,64,'+')):
            d.rounded_rectangle((x*SCALE,315*SCALE,(x+w)*SCALE,351*SCALE),radius=10*SCALE,fill='#253423');text(img,x+w/2,318,label,23)
        text(img,208,355,'Dra kart · zoom +/−',17,'#A6AD9F')
    text(img,208,35,title,26); d.line((68*SCALE,78*SCALE,348*SCALE,78*SCALE),fill='#33382E',width=SCALE)
    mask=Image.new('L',img.size,0);ImageDraw.Draw(mask).ellipse((0,0,img.width-1,img.height-1),fill=255)
    out=Image.new('RGB',img.size,'#E7EBE1');out.paste(img,(0,0),mask)
    return out

def main():
    data=json.loads((ROOT/'data/courses.json').read_text());course=data['courses'][0];hole=course['holes'][0]
    resource=json.loads((ROOT/'resources/courses/bogstad1.json').read_text())
    img=Image.new('RGB',(1440*SCALE,600*SCALE),'#E7EBE1')
    text(img,720,25,'Golf App · Venu 2 · Bogstad hull 1',30,'#203225')
    for x,mode in ((45,'main'),(512,'map'),(979,'green')):img.paste(face(hole,resource,mode),(x*SCALE,95*SCALE))
    text(img,720,530,'Designforhåndsvisning fra ekte OSM-geometri · ikke et simulatorbilde',20,'#3D533D')
    text(img,720,562,'© OpenStreetMap contributors · trær i skogflater er illustrerende karttegn',17,'#60705B')
    output=ROOT/'docs/ui-preview.png';img.save(output);print(output)

if __name__=='__main__':main()
