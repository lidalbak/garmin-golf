import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.System;

// Real Garmin Storage, isolated from the user's active round and history.
class GolfRuntimeTestStore extends GolfDeviceStore {
    var owned=[]; var prefix;
    function initialize() { prefix="runtime-test/"+Time.now().value()+"-"+System.getTimer()+"/"; }
    function get(key) { return Application.Storage.getValue(prefix+key); }
    function set(key,value) {
        if(owned.indexOf(key)==-1) { owned.add(key); }
        Application.Storage.setValue(prefix+key,value);
    }
    function remove(key) { Application.Storage.deleteValue(prefix+key); }
    function cleanup() { for(var i=0;i<owned.size();i+=1) { remove(owned[i]); } }
}
(:test)
function realStorageResumesRoundAndArchivesFullShotLog(logger) {
    var store=new GolfRuntimeTestStore(); var result=false;
    try {
        var state=new GolfState(store);
        if(!state.begin(0)) { throw new Lang.InvalidValueException("Cannot begin"); }
        state.updateScore(0,1); state.pins[0]=state.hole()["center"];
        state.shotClub=0; state.startShot(state.hole()["tee"]);
        var resumed=new GolfState(store); resumed.resume();
        if(resumed.course==null || resumed.log.pending==null || resumed.cards[0][0]!=1 || resumed.pins[0]==null) { throw new Lang.InvalidValueException("Cannot resume"); }
        resumed.finishShot(resumed.hole()["center"]);
        for(var i=1;i<100;i+=1) { resumed.addManualShot("iron7",false); }
        var id=resumed.roundId; resumed.archive();
        var loaded=new GolfState(store); var log=loaded.archivedLog(id);
        result=loaded.saved==null && loaded.history.size()==1 && log!=null && log.entries.size()==100 && log.entries[0]["distance"]>0;
    } catch(e) { logger.error(e.getErrorMessage()); }
    store.cleanup(); return result;
}
