// Generated from data/map-layout.json by scripts/generate_courses.py.
import Toybox.Math;
module MapLayout {
 const mainViewport = [208,78,208,338];
 const mainFit = [224,88,166,252];
 const detailViewport = [0,78,416,276];
 const detailFit = [60,88,296,223];
 const profile = [[78,232,321],[115,222,344],[170,216,353],[225,214,374],[290,217,406],[350,225,416],[416,236,416]];
 function mainSpan(y) {
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
}
