import Toybox.Graphics;

// Exercise the production drawing path with actual course resources in Garmin runtime.
class GolfRenderHarness {
    var state; var message=null;
    function initialize() { state=new GolfState(new GolfTestStore()); }
    function livePosition() { return state.hole()["tee"]; }
}
(:test)
function everyCourseHoleRendersMainMapAndGreen(logger) {
    var app=new GolfRenderHarness();
    var bitmap=Graphics.createBufferedBitmap({:width=>416,:height=>416}).get();
    var view=new GolfView(app);
    for(var c=0;c<app.state.catalog.size();c+=1) {
        app.state=new GolfState(new GolfTestStore()); if(!app.state.begin(c)) { return false; }
        for(var h=0;h<app.state.cards.size();h+=1) {
            app.state.holeIndex=h;
            logger.debug("Render course "+c+" hole "+h);
            view.page="hole"; view.onUpdate(bitmap.getDc()); if(view.transform==null) { return false; } view.onHide();
            view.page="green"; view.onUpdate(bitmap.getDc()); if(view.transform==null) { return false; } view.onHide();
        }
    }
    return true;
}
(:test)
function scoreAndBigNumbersRenderWithKnownGps(logger) {
    var app=new GolfRenderHarness(); if(!app.state.begin(0)) { return false; }
    var bitmap=Graphics.createBufferedBitmap({:width=>416,:height=>416}).get();
    var view=new GolfView(app);
    app.state.bigNumbers=true; view.page="hole"; view.onUpdate(bitmap.getDc());
    app.state.updateScore(0,1); view.page="score"; view.onUpdate(bitmap.getDc());
    view.onHide(); return true;
}

(:test)
function mapZoomAndPanPreserveTargetCoordinate(logger) {
    var app=new GolfRenderHarness(); if(!app.state.begin(0)) { return false; }
    var bitmap=Graphics.createBufferedBitmap({:width=>416,:height=>416}).get();
    var view=new GolfView(app); view.page="map"; view.onUpdate(bitmap.getDc());
    var scale=view.transform[5]; view.changeZoom(1.5); view.onUpdate(bitmap.getDc());
    if((view.transform[5]/scale-1.5).abs()>0.001) { return false; }
    var target=app.state.target(); var before=view.screen(target);
    view.panX=30; view.panY=-20; view.onUpdate(bitmap.getDc());
    var after=view.screen(target); var restored=view.fromScreen(after[0],after[1]);
    var valid=(after[0]-before[0]-30).abs()<=1 && (after[1]-before[1]+20).abs()<=1 && Geo.distance(target,restored)<2;
    view.onHide(); return valid;
}
