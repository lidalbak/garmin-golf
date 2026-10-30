"""Presentation boundaries, separate from the actual course geometry."""
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
LAYOUT=json.loads((ROOT/'data/map-layout.json').read_text())

def main_span(y):
    profile=LAYOUT['mainProfile']
    for a,b in zip(profile,profile[1:]):
        if a[0]<=y<=b[0]:
            t=(1-math.cos(math.pi*(y-a[0])/(b[0]-a[0])))/2
            return [a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t]
    return [416,416]

def generate():
    def array(value): return json.dumps(value,separators=(',',':'))
    code='// Generated from data/map-layout.json by scripts/generate_courses.py.\nimport Toybox.Math;\nmodule MapLayout {\n'
    for mode in ('main','detail'):
        for kind in ('viewport','fit'):
            code+=' const '+mode+kind.title()+' = '+array(LAYOUT[mode][kind])+';\n'
    code+=' const profile = '+array(LAYOUT['mainProfile'])+';\n'
    code+=''' function mainSpan(y) {
        for(var i=0;i<profile.size()-1;i+=1) {
            var a=profile[i]; var b=profile[i+1];
            if(y>=a[0] && y<=b[0]) {
                var t=(1.0-Math.cos(3.141592653589793*(y-a[0])/(b[0]-a[0])))/2.0;
                return [a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t];
            }
        }
        return [416,416];
    }
    function mainContains(x,y) {
        var span=mainSpan(y); var dx=x-208; var dy=y-208;
        return x>=span[0] && x<=span[1] && dx*dx+dy*dy<=208*208;
    }
}\n'''
    (ROOT/'source/MapLayout.mc').write_text(code)
