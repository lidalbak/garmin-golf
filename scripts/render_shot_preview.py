#!/usr/bin/env python3
"""Menu sketch and shot-screen design preview. Example data, not Garmin runtime."""
from PIL import Image,ImageDraw
from render_preview import text,SCALE,ROOT

def frame(mode):
    image=Image.new('RGB',(416*SCALE,416*SCALE),'black'); d=ImageDraw.Draw(image)
    def title(value):
        text(image,208,35,value,26);d.line((68*SCALE,78*SCALE,348*SCALE,78*SCALE),fill='#33382E',width=SCALE)
    def button(x,y,w,label):
        d.rounded_rectangle((x*SCALE,y*SCALE,(x+w)*SCALE,(y+45)*SCALE),radius=12*SCALE,fill='#203727');text(image,x+w/2,y+8,label,23)
    if mode=='menu':
        title('Golfmeny')
        for y,label in ((92,'Vis green'),(139,'Vis kart'),(186,'Kølleforslag'),(233,'Bytt hull'),(280,'Scorekort'),(327,'Mål slag')):
            text(image,208,y,label,25)
            if y<327:d.line((84*SCALE,(y+38)*SCALE,332*SCALE,(y+38)*SCALE),fill='#252A23',width=SCALE)
    elif mode=='measurement':
        title('Måler fra hull 1');text(image,208,99,'7 jern',30)
        text(image,208,150,'154',80,'#FFDE00',True)
        text(image,208,239,'meter · avslutt ved ballen',17,'#A6AD9F')
        button(78,274,260,'Fullfør slag')
        text(image,208,328,'Kølle · historikk · avbryt',17)
        text(image,208,355,'Manuell måling · score separat',17,'#A6AD9F')
    else:
        title('Slag · hull 1');text(image,208,99,'7 jern',30)
        text(image,208,148,'154',80,'#FFDE00',True)
        text(image,208,238,'meter · GPS inkl. rull',17,'#A6AD9F')
        button(58,288,142,'Rediger');button(216,288,142,'Nytt slag')
        text(image,208,355,'Slagloggen endrer ikke scoren',17,'#A6AD9F')
    mask=Image.new('L',image.size,0);ImageDraw.Draw(mask).ellipse((0,0,image.width-1,image.height-1),fill=255)
    out=Image.new('RGB',image.size,'#E7EBE1');out.paste(image,(0,0),mask);return out

def main():
    image=Image.new('RGB',(1440*SCALE,600*SCALE),'#E7EBE1')
    text(image,720,25,'Golf App · meny og slagregistrering',30,'#203225')
    for x,mode in ((45,'menu'),(512,'measurement'),(979,'detail')):image.paste(frame(mode),(x*SCALE,95*SCALE))
    text(image,720,530,'Menyskisse og designvisning · eksempeldata · ikke et simulatorbilde',20,'#3D533D')
    text(image,720,562,'Velg kølle, mål slag, rett eller slett · score føres separat',18,'#60705B')
    p=ROOT/'docs/shot-preview.png';image.save(p);print(p)

if __name__=='__main__':main()
