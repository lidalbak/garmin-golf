import Toybox.Math;

// All public coordinates are latitude/longitude in degrees, all distances meters.
module Geo {
    const RAD = 0.017453292519943295;
    const EARTH = 6371008.8;

    function distance(a, b) {
        var lat = (b[0] - a[0]) * RAD;
        var lon = (b[1] - a[1]) * RAD;
        var x = Math.sin(lat / 2.0);
        var y = Math.sin(lon / 2.0);
        var h = x*x + Math.cos(a[0]*RAD)*Math.cos(b[0]*RAD)*y*y;
        h = GolfNumbers.min(1.0, GolfNumbers.max(0.0, h));
        return 2.0 * EARTH * Math.atan2(Math.sqrt(h), Math.sqrt(1.0-h));
    }

    function bearing(a, b) {
        var dl = (b[1]-a[1])*RAD;
        var y = Math.sin(dl)*Math.cos(b[0]*RAD);
        var x = Math.cos(a[0]*RAD)*Math.sin(b[0]*RAD) - Math.sin(a[0]*RAD)*Math.cos(b[0]*RAD)*Math.cos(dl);
        var deg = Math.atan2(y,x)/RAD;
        if (deg < 0) { deg += 360.0; }
        return deg;
    }

    // Local tangent plane: east/north meters, adequate for an individual golf hole.
    function project(p, origin) {
        return [(p[1]-origin[1])*RAD*EARTH*Math.cos(origin[0]*RAD), (p[0]-origin[0])*RAD*EARTH];
    }
    function unproject(p, origin) {
        return [origin[0]+p[1]/(RAD*EARTH), origin[1]+p[0]/(RAD*EARTH*Math.cos(origin[0]*RAD))];
    }
    function contains(p, ring) {
        if (ring == null || ring.size() < 3) { return false; }
        var inside = false;
        var j = ring.size()-1;
        for (var i=0; i<ring.size(); i+=1) {
            if ((ring[i][1]>p[1]) != (ring[j][1]>p[1])) {
                if (p[0] < (ring[j][0]-ring[i][0])*(p[1]-ring[i][1])/(ring[j][1]-ring[i][1])+ring[i][0]) { inside = !inside; }
            }
            j=i;
        }
        return inside;
    }

    function boundaryDistance(player,ring) {
        if(ring==null || ring.size()<2) { return null; }
        if(contains(player,ring)) { return 0.0; }
        var nearest=null;
        for(var i=0;i<ring.size();i+=1) {
            var a=project(ring[i],player); var b=project(ring[(i+1)%ring.size()],player);
            var dx=b[0]-a[0]; var dy=b[1]-a[1]; var squared=dx*dx+dy*dy;
            var t=squared==0 ? 0 : GolfNumbers.max(0.0,GolfNumbers.min(1.0,-(a[0]*dx+a[1]*dy)/squared));
            var xx=a[0]+t*dx; var yy=a[1]+t*dy; var d=Math.sqrt(xx*xx+yy*yy);
            if(nearest==null || d<nearest) { nearest=d; }
        }
        return nearest;
    }

    // Intersect the player-to-target line with the actual mapped green boundary.
    // Missing boundary and being inside the green remain unknown, not +/- guessed meters.
    function greenEdges(player, target, ring) {
        if (ring == null || ring.size()<3 || contains(player,ring)) { return null; }
        var d=project(target,player);
        var length=Math.sqrt(d[0]*d[0]+d[1]*d[1]);
        if (length<1) { return null; }
        var lo=null; var hi=null;
        for (var i=0;i<ring.size();i+=1) {
            var a=project(ring[i],player);
            var b=project(ring[(i+1)%ring.size()],player);
            var e=[b[0]-a[0],b[1]-a[1]];
            var cross=d[0]*e[1]-d[1]*e[0];
            if (GolfNumbers.abs(cross)<0.000001) { continue; }
            var t=(a[0]*e[1]-a[1]*e[0])/cross;
            var u=(a[0]*d[1]-a[1]*d[0])/cross;
            if (t>=0 && u>=0 && u<=1) {
                var meters=t*length;
                if (lo==null || meters<lo) { lo=meters; }
                if (hi==null || meters>hi) { hi=meters; }
            }
        }
        if (lo==null || hi==null || hi-lo<0.01) { return null; }
        return [lo,hi];
    }
}
