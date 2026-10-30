import Toybox.Math;

module GolfRules {
    function strokesForHole(playingHandicap, index, holeCount) {
        if (index==null || index<1 || index>holeCount) { return null; }
        var base=Math.floor(playingHandicap.toFloat()/holeCount).toNumber();
        var remainder=playingHandicap-base*holeCount;
        return base+(index<=remainder ? 1 : 0);
    }
    function stableford(strokes, par, received) {
        if (strokes==null || par==null || received==null) { return null; }
        return GolfNumbers.max(0,2+par+received-strokes);
    }
    function recommend(clubs, meters) {
        if (meters==null) { return null; }
        var selected=null; var error=null;
        for (var i=0;i<clubs.size();i+=1) {
            var carry=clubs[i][1];
            if (carry==null || carry<=0) { continue; }
            var diff=GolfNumbers.abs(carry-meters);
            if (error==null || diff<error) { selected=clubs[i][0]; error=diff; }
        }
        return selected;
    }
}
