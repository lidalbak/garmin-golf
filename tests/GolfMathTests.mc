import Toybox.Test;
import Toybox.Math;

(:test)
function identicalLocations(logger) {
    return Geo.distance([59.96d,10.63d],[59.96d,10.63d])==0;
}
(:test)
function equatorialDistance(logger) {
    return GolfNumbers.abs(Geo.distance([0.0d,0.0d],[0.0d,1.0d])-111195.080)<1;
}
(:test)
function eastBearing(logger) {
    return GolfNumbers.abs(Geo.bearing([0.0d,0.0d],[0.0d,1.0d])-90)<0.001;
}
(:test)
function coordinateRoundTrip(logger) {
    var origin=[59.9627802d,10.6384708d]; var target=[59.9652832d,10.6354659d];
    return Geo.distance(target,Geo.unproject(Geo.project(target,origin),origin))<0.01;
}
(:test)
function greenCoverageIsUnknownWithoutPolygon(logger) {
    return Geo.greenEdges([0.0d,0.0d],[0.001d,0.0d],null)==null;
}
(:test)
function greenLineIntersections(logger) {
    var player=[0.0d,0.0d]; var target=[0.002d,0.0d];
    var ring=[[0.001d,-0.001d],[0.003d,-0.001d],[0.003d,0.001d],[0.001d,0.001d]];
    var edges=Geo.greenEdges(player,target,ring);
    return edges!=null && GolfNumbers.abs(edges[0]-111.195)<0.1 && GolfNumbers.abs(edges[1]-333.585)<0.1 && Geo.greenEdges(target,target,ring)==null;
}
(:test)
function handicapAllocation(logger) {
    var total=0;
    for(var i=1;i<=18;i+=1) { total+=GolfRules.strokesForHole(25,i,18); }
    return total==25 && GolfRules.strokesForHole(25,7,18)==2 && GolfRules.strokesForHole(25,8,18)==1 && GolfRules.strokesForHole(25,null,18)==null;
}
(:test)
function plusHandicapAllocation(logger) {
    var total=0;
    for(var i=1;i<=18;i+=1) { total+=GolfRules.strokesForHole(-2,i,18); }
    return total==-2 && GolfRules.strokesForHole(-2,17,18)==-1 && GolfRules.strokesForHole(-2,1,18)==0;
}
(:test)
function stablefordUncertaintyAndFloor(logger) {
    return GolfRules.stableford(4,4,0)==2 && GolfRules.stableford(10,4,1)==0 && GolfRules.stableford(4,4,null)==null && GolfRules.stableford(null,4,0)==null;
}
(:test)
function noInventedClubCarry(logger) {
    return GolfRules.recommend([["Driver",null]],150)==null && GolfRules.recommend([["7 jern",140],["8 jern",125]],130).equals("8 jern");
}
