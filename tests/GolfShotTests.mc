import Toybox.Lang;

// A serialization-like fake: mutable values never alias committed device storage.
class GolfTestStore {
    var values={}; var failSet=null; var failRemove=null;
    function initialize() {}
    function copy(value) {
        if(value instanceof Array) { var a=[]; for(var i=0;i<value.size();i+=1) { a.add(copy(value[i])); } return a; }
        if(value instanceof Dictionary) { var d={}; var keys=value.keys(); for(var j=0;j<keys.size();j+=1) { d[keys[j]]=copy(value[keys[j]]); } return d; }
        return value;
    }
    function get(key) { return copy(values[key]); }
    function set(key,value) {
        if(failSet!=null && failSet.equals(key)) { throw new Lang.InvalidValueException("Injected write failure"); }
        values[key]=copy(value);
    }
    function remove(key) {
        if(failRemove!=null && failRemove.equals(key)) { throw new Lang.InvalidValueException("Injected remove failure"); }
        values.remove(key);
    }
}

(:test)
function shotKeepsOriginAndClubAcrossHoleChange(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store);
    if(!state.begin(0)) { return false; }
    state.shotClub=0;
    if(!state.startShot([59.96d,10.63d])) { return false; }
    state.shotClub=2; state.changeHole(1);
    var reloaded=new GolfState(store); reloaded.resume();
    var shot=reloaded.finishShot([59.9605d,10.63d]);
    return shot!=null && shot["hole"]==0 && shot["clubId"].equals("driver") && reloaded.holeIndex==1 && reloaded.log.pending==null && !reloaded.dirty;
}

(:test)
function stableShotIdsSurviveDeletionAndCorrection(logger) {
    var log=new GolfShotLog(); var first=log.addManual(0,"driver",1,1); var second=log.addManual(0,"iron7",1,2);
    if(!log.remove(first["id"]) || !log.changeClub(second["id"],"sw")) { return false; }
    var third=log.addManual(1,null,1,3);
    return log.find(1)==null && log.find(2)["clubId"].equals("sw") && third["id"]==3 && log.entries.size()==2;
}

(:test)
function unknownDistanceAndClubAreNotInvented(logger) {
    var log=new GolfShotLog(); var manual=log.addManual(0,null,1,1); var putt=log.addManual(0,"putter",2,2);
    var stats=log.stats("putter");
    return manual["clubId"]==null && manual["distance"]==null && manual["start"]==null && putt["distance"]==null && stats["average"]==null && stats["measured"]==0;
}

(:test)
function sourcePointsAreCopiedAtMeasurementBoundary(logger) {
    var log=new GolfShotLog(); var p=[59.96d,10.63d];
    log.start(0,"iron7",p,1); p[0]=0;
    var shot=log.finish([59.9605d,10.63d],2);
    return shot["start"][0]==59.96d && shot["distance"]>50 && shot["distance"]<60;
}

(:test)
function compactShotStoragePreservesPendingAndUnknowns(logger) {
    var log=new GolfShotLog(); log.addManual(0,null,1,1); log.start(2,"putter",[59.96d,10.63d],2);
    var restored=new GolfShotLog();
    if(!restored.load(log.serialize(),18)) { return false; }
    return restored.nextId==2 && restored.pending["hole"]==2 && restored.pending["clubId"].equals("putter") && restored.entries[0]["distance"]==null;
}

(:test)
function malformedShotLoadIsAtomic(logger) {
    var log=new GolfShotLog(); log.addManual(0,"driver",1,1);
    var duplicate=[3,null,[[1,0,"driver",1,null,null,null,1],[1,0,"sw",1,null,null,null,2]]];
    return !log.load(duplicate,18) && log.entries.size()==1 && log.nextId==2 && log.find(1)["clubId"].equals("driver");
}

(:test)
function shotCapacityDoesNotCreatePartialRecords(logger) {
    var log=new GolfShotLog();
    for(var i=0;i<100;i+=1) { if(log.addManual(0,null,1,i)==null) { return false; } }
    return log.addManual(0,null,1,101)==null && !log.start(0,"driver",[59.96d,10.63d],102) && log.entries.size()==100 && log.nextId==101 && log.pending==null;
}

(:test)
function statisticsDistinguishTotalDistanceFromCarry(logger) {
    var log=new GolfShotLog(); log.start(0,"iron7",[0.0d,0.0d],1); var shot=log.finish([0.001d,0.0d],2); log.addManual(0,"iron7",1,3);
    var stats=log.stats("iron7");
    return stats["count"]==2 && stats["measured"]==1 && stats["average"]==shot["distance"] && stats["longest"]==shot["distance"];
}

(:test)
function shotRegistrationDoesNotDoubleCountScore(logger) {
    var state=new GolfState(new GolfTestStore()); state.begin(0); state.updateScore(0,1);
    var shot=state.addManualShot("putter",true);
    return shot!=null && state.total()==1 && state.cards[0][1]==0 && state.log.entries.size()==1;
}

(:test)
function failedShotSaveRetainsRetryableMeasurement(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0);
    store.failSet="active-v1";
    if(!state.startShot([59.96d,10.63d]) || !state.dirty || state.log.pending==null) { return false; }
    store.failSet=null;
    if(!state.save() || state.dirty) { return false; }
    var restored=new GolfState(store); restored.resume(); return restored.log.pending!=null;
}

(:test)
function failedFinishSaveDoesNotDuplicateShotOnRetry(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0); state.startShot([59.96d,10.63d]);
    store.failSet="active-v1";
    var shot=state.finishShot([59.9605d,10.63d]);
    if(shot==null || !state.dirty || state.log.pending!=null) { return false; }
    store.failSet=null; if(!state.save()) { return false; }
    var restored=new GolfState(store); restored.resume(); return restored.log.entries.size()==1 && restored.log.find(shot["id"])!=null;
}

(:test)
function legacyRoundAndBagMigrateWithoutLosingFacts(logger) {
    var store=new GolfTestStore(); var bag=GolfClubs.defaults(); var oldBag=[];
    for(var b=0;b<10;b+=1) { oldBag.add([bag[b][0],100+b]); }
    store.set("settings-v1",{"clubs"=>oldBag,"handicap"=>12,"yards"=>true,"tournament"=>false});
    var cards=[]; var pins=[]; for(var i=0;i<18;i+=1) { cards.add([null,0,0,0]); pins.add(null); }
    store.set("active-v1",{"course"=>"bogstad","hole"=>1,"cards"=>cards,"pins"=>pins,"started"=>123,"shotClub"=>7,"shotStart"=>[59.96d,10.63d],"shots"=>[[0,1,123.25d,[59.96d,10.63d],[59.961d,10.63d]]]});
    var state=new GolfState(store); state.resume();
    if(state.clubs.size()!=14 || state.clubs[0][1]!=100 || state.clubs[10][1]!=null || state.log.entries[0]["distance"]!=123.25d || !state.log.entries[0]["clubId"].equals("wood3") || state.log.pending["hole"]!=1) { return false; }
    if(!state.save()) { return false; }
    var raw=store.get("active-v1");
    var restored=new GolfState(store); restored.resume();
    return raw["version"]==2 && !raw.hasKey("shots") && restored.log.entries.size()==1 && restored.log.pending["clubId"].equals("iron9") && restored.handicap==12 && restored.yards;
}

(:test)
function archiveRefusesToLosePendingShot(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0); state.startShot([59.96d,10.63d]);
    return !state.archive() && state.course!=null && store.get("active-v1")!=null && state.log.pending!=null && state.historyNew.size()==0;
}

(:test)
function archiveIndexFailureRemainsOwnedAndRetryable(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0); state.addManualShot("driver",false); var id=state.roundId;
    store.failSet="history-v2";
    if(state.archive() || state.course==null || store.get(id)==null || store.get("active-v1")==null) { return false; }
    store.failSet=null;
    return state.archive() && state.historyNew.size()==1 && state.historyNew[0]["id"].equals(id) && state.archivedLog(id).entries.size()==1;
}

(:test)
function partialArchiveRetryDoesNotDuplicateHistory(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0); state.addManualShot("sw",false); var id=state.roundId;
    store.failRemove="active-v1";
    if(state.archive() || state.historyNew.size()!=1 || state.course==null) { return false; }
    store.failRemove=null;
    var restored=new GolfState(store); restored.resume();
    return restored.archive() && restored.historyNew.size()==1 && restored.historyNew[0]["id"].equals(id) && store.get("active-v1")==null;
}

(:test)
function historyCleanupFailureRetainsOwnershipUntilRetry(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store);
    for(var i=0;i<10;i+=1) { if(!state.begin(0) || !state.archive()) { return false; } }
    store.failRemove="round-1";
    if(!state.begin(0) || !state.archive() || state.cleanupPending.size()!=1 || store.get("round-1")==null) { return false; }
    var restored=new GolfState(store);
    if(restored.retryCleanup() || restored.cleanupPending.size()!=1) { return false; }
    store.failRemove=null;
    return restored.retryCleanup() && restored.cleanupPending.size()==0 && store.get("round-1")==null && restored.historyNew.size()==10;
}

(:test)
function cleanupCannotDeleteRetainedRound(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0); state.archive();
    state.cleanupPending=["round-1"];
    return !state.retryCleanup() && store.get("round-1")!=null;
}

(:test)
function archivedClubNameDoesNotFollowCurrentBag(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.clubs[0][0]="Min driver";
    state.begin(0); state.addManualShot("driver",false); var id=state.roundId;
    if(!state.archive()) { return false; }
    state.clubs[0][0]="Ny driver";
    return state.archivedLog(id).clubName("driver").equals("Min driver");
}

(:test)
function archiveIdentityMismatchIsNotAttributedToSelectedRound(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0); var id=state.roundId; state.archive();
    var full=store.get(id); full["roundId"]="round-999"; store.set(id,full);
    return state.archivedLog(id)==null && state.storageError!=null && store.get(id)!=null;
}

(:test)
function pendingMeasurementReservesItsStorageSlot(logger) {
    var log=new GolfShotLog();
    for(var i=0;i<99;i+=1) { log.addManual(0,null,1,i); }
    if(!log.start(0,"driver",[59.96d,10.63d],100) || log.addManual(0,null,1,101)!=null) { return false; }
    return log.finish([59.961d,10.63d],102)!=null && log.entries.size()==100 && log.pending==null;
}

(:test)
function blockedStorageCannotReportNewMeasurementAsSaved(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store); state.begin(0);
    state.storageReady=false; state.storageError="Unreadable storage";
    return state.startShot([59.96d,10.63d]) && state.dirty && state.log.pending!=null && store.get("active-v1")["shotLog"][1]==null;
}

(:test)
function searchAlarmFiresOnceAtDeadlineAndCanRestart(logger) {
    var state=new GolfState(new GolfTestStore()); state.searchUntil=180;
    if(state.consumeSearchAlarm(179) || !state.consumeSearchAlarm(180) || state.consumeSearchAlarm(181)) { return false; }
    state.searchUntil=400;
    return !state.consumeSearchAlarm(399) && state.consumeSearchAlarm(500) && !state.consumeSearchAlarm(501);
}

(:test)
function bigNumbersSettingsRemainBackwardCompatible(logger) {
    var store=new GolfTestStore(); var state=new GolfState(store);
    state.saveSettings(); var settings=store.get("settings-v1"); settings.remove("bigNumbers"); store.set("settings-v1",settings);
    var old=new GolfState(store); if(old.bigNumbers || !old.storageReady) { return false; }
    old.bigNumbers=true; old.saveSettings(); var current=new GolfState(store);
    if(!current.bigNumbers || !current.storageReady) { return false; }
    settings=store.get("settings-v1"); settings["bigNumbers"]="true"; store.set("settings-v1",settings);
    return !new GolfState(store).storageReady;
}
