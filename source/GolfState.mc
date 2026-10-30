import Toybox.Lang;
import Toybox.Time;

// Owns parsed round facts and the commit/cleanup lifecycle. No UI reads raw storage.
class GolfState {
    var store;
    var course=null; var courseIndex=0; var holeIndex=0;
    var cards=[]; var pins=[]; var log;
    var clubs; var shotClub=null;
    var handicap=0; var tournament=false; var yards=false; var bigNumbers=false;
    var started=null; var roundId=null; var searchUntil=null;
    var storageError=null; var storageReady=true; var dirty=false;
    var history=[]; var historyNew=[]; var historyLegacy=[]; var cleanupPending=[];
    var catalog; var saved=null;

    function initialize(adapter) {
        store=adapter; catalog=Courses.catalog(); clubs=GolfClubs.defaults(); log=new GolfShotLog();
        try {
            var settings=store.get("settings-v1");
            if(settings!=null && !readSettings(settings)) { storageReady=false; storageError="Innstillinger kan ikke leses"; }
            var old=store.get("history-v1");
            if(old!=null) {
                if(validHistory(old,false)) { historyLegacy=old; }
                else { storageReady=false; storageError="Eldre historikk kan ikke leses"; }
            }
            var index=store.get("history-v2");
            if(index!=null) {
                if(index instanceof Dictionary && validHistory(index["entries"],true) && validCleanup(index["cleanup"])) {
                    historyNew=index["entries"]; cleanupPending=index["cleanup"];
                } else { storageReady=false; storageError="Rundehistorikk kan ikke leses"; }
            }
            refreshHistory();
            var active=store.get("active-v1");
            if(active!=null) {
                if(validRound(active)) { saved=active; }
                else { storageReady=false; storageError="Lagret runde kan ikke leses"; }
            }
        } catch(e) { storageReady=false; storageError="Kunne ikke lese lagring"; }
    }
    function readSettings(s) {
        if(!(s instanceof Dictionary) || !(s["clubs"] instanceof Array) || (s["clubs"].size()!=10 && s["clubs"].size()!=GolfClubs.IDS.size())) { return false; }
        var parsed=GolfClubs.defaults();
        for(var i=0;i<s["clubs"].size();i+=1) {
            var c=s["clubs"][i];
            if(!(c instanceof Array) || c.size()!=2 || !(c[0] instanceof String) || (c[1]!=null && (!(c[1] instanceof Number) || c[1]<1 || c[1]>400))) { return false; }
            parsed[i]=[c[0],c[1]];
        }
        if(!(s["handicap"] instanceof Number) || s["handicap"]< -10 || s["handicap"]>54 || !(s["yards"] instanceof Boolean) || !(s["tournament"] instanceof Boolean)) { return false; }
        if(s.hasKey("bigNumbers") && !(s["bigNumbers"] instanceof Boolean)) { return false; }
        bigNumbers=s.hasKey("bigNumbers") ? s["bigNumbers"] : false;
        clubs=parsed; handicap=s["handicap"]; yards=s["yards"]; tournament=s["tournament"]; return true;
    }
    function clubId() { return shotClub==null ? null : GolfClubs.IDS[shotClub]; }
    function clubName(id) { var i=GolfClubs.index(id); return i==null ? "Ukjent kølle" : clubs[i][0]; }
    function readLog(r,holeCount) {
        var parsed=new GolfShotLog();
        var valid=false;
        if(r["version"]==2) { valid=parsed.load(r["shotLog"],holeCount); }
        else if(r["version"]==null) { valid=parsed.loadLegacy(r["shots"],r["shotStart"],r["shotClub"],r["hole"],r["started"],holeCount); }
        return valid ? parsed : null;
    }
    function validRound(r) {
        if(!(r instanceof Dictionary) || !(r["course"] instanceof String) || !(r["hole"] instanceof Number) || !(r["cards"] instanceof Array) || !(r["pins"] instanceof Array) || !(r["started"] instanceof Number)) { return false; }
        if(r["version"]!=null && r["version"]!=2) { return false; }
        if(r["version"]==2 && (!validRoundId(r["roundId"]) || !GolfClubs.valid(r["selectedClub"]))) { return false; }
        var found=null;
        for(var i=0;i<catalog.size();i+=1) { if(catalog[i]["id"].equals(r["course"])) { found=catalog[i]; } }
        if(found==null || r["cards"].size()!=found["holes"].size() || r["pins"].size()!=found["holes"].size() || r["hole"]<0 || r["hole"]>=found["holes"].size()) { return false; }
        for(var j=0;j<r["cards"].size();j+=1) {
            var c=r["cards"][j];
            if(!(c instanceof Array) || c.size()!=4 || (c[0]!=null && (!(c[0] instanceof Number) || c[0]<1 || c[0]>30)) || !(c[1] instanceof Number) || c[1]<0 || c[1]>10 || !(c[2] instanceof Number) || c[2]<0 || c[2]>10 || !(c[3] instanceof Number) || c[3]<0 || c[3]>3) { return false; }
            if(c[0]!=null && c[0]<c[1]+c[2]) { return false; }
            if(r["pins"][j]!=null && !log.coordinate(r["pins"][j])) { return false; }
        }
        return readLog(r,found["holes"].size())!=null;
    }
    function validRoundId(id) {
        if(!(id instanceof String) || id.find("round-")!=0) { return false; }
        var sequence=id.substring(6,id.length()).toNumber();
        return sequence!=null && sequence>0 && id.equals("round-"+sequence);
    }
    function validHistory(h,modern) {
        if(!(h instanceof Array) || h.size()>10) { return false; }
        var ids={};
        for(var i=0;i<h.size();i+=1) {
            var r=h[i];
            if(!(r instanceof Dictionary) || !(r["course"] instanceof String) || !(r["strokes"] instanceof Number) || r["strokes"]<0 || !(r["played"] instanceof Number) || r["played"]<0 || r["played"]>36 || !(r["started"] instanceof Number)) { return false; }
            if(modern) { if(!validRoundId(r["id"]) || ids.hasKey(r["id"])) { return false; } ids[r["id"]]=true; }
        }
        return true;
    }
    function validCleanup(values) {
        if(!(values instanceof Array) || values.size()>10) { return false; }
        for(var i=0;i<values.size();i+=1) { if(!validRoundId(values[i])) { return false; } }
        return true;
    }
    function refreshHistory() {
        history=[];
        for(var i=0;i<historyNew.size();i+=1) { history.add(historyNew[i]); }
        for(var j=0;j<historyLegacy.size() && history.size()<10;j+=1) {
            var old=historyLegacy[j]; history.add({"id"=>"legacy-"+j,"course"=>old["course"],"strokes"=>old["strokes"],"played"=>old["played"],"started"=>old["started"]});
        }
    }
    function allocateId() {
        var next=store.get("next-round-v2");
        if(next==null) { next=1; }
        if(!(next instanceof Number) || next<1 || next>=2147483647) { throw new Lang.InvalidValueException("Invalid round sequence"); }
        var id="round-"+next;
        if(store.get(id)!=null) { throw new Lang.InvalidValueException("Round identity already exists"); }
        store.set("next-round-v2",next+1); return id;
    }
    function resume() {
        if(saved==null) { return; }
        for(var i=0;i<catalog.size();i+=1) { if(catalog[i]["id"].equals(saved["course"])) { courseIndex=i; course=catalog[i]; } }
        holeIndex=saved["hole"]; cards=saved["cards"]; pins=saved["pins"]; started=saved["started"];
        roundId=saved["version"]==2 ? saved["roundId"] : null;
        shotClub=saved["version"]==2 ? GolfClubs.index(saved["selectedClub"]) : saved["shotClub"];
        log=readLog(saved,cards.size());
    }
    function begin(index) {
        if(!storageReady || saved!=null || course!=null || index<0 || index>=catalog.size() || catalog[index]["holes"].size()==0) { return false; }
        try { roundId=allocateId(); }
        catch(e) { storageError="Kunne ikke opprette rundelagring"; return false; }
        courseIndex=index; course=catalog[index]; holeIndex=0; cards=[]; pins=[]; log=new GolfShotLog();
        for(var i=0;i<course["holes"].size();i+=1) { cards.add([null,0,0,0]); pins.add(null); }
        started=Time.now().value(); save(); return true;
    }
    function record() {
        return {"version"=>2,"roundId"=>roundId,"course"=>course["id"],"hole"=>holeIndex,"cards"=>cards,"pins"=>pins,"started"=>started,"shotLog"=>log.serialize(),"selectedClub"=>clubId()};
    }
    function save() {
        if(course==null) { return false; }
        dirty=true;
        if(!storageReady) { return false; }
        try {
            if(roundId==null) { roundId=allocateId(); }
            store.set("active-v1",record()); saved=record(); storageError=null; dirty=false; return true;
        } catch(e) { storageError="Lagring feilet. Behold appen åpen."; return false; }
    }
    function saveSettings() {
        if(!storageReady) { return false; }
        try { store.set("settings-v1",{"clubs"=>clubs,"handicap"=>handicap,"yards"=>yards,"tournament"=>tournament,"bigNumbers"=>bigNumbers}); if(!dirty) { storageError=null; } return true; }
        catch(e) { storageError="Innstillinger ble ikke lagret"; return false; }
    }
    function consumeSearchAlarm(now) {
        if(searchUntil==null || now<searchUntil) { return false; }
        searchUntil=null; return true;
    }
    function hole() { return course["holes"][holeIndex]; }
    function target() { return pins[holeIndex]!=null ? pins[holeIndex] : hole()["center"]; }
    function card() { return cards[holeIndex]; }
    function changeHole(delta) { return selectHole(holeIndex+delta); }
    function selectHole(index) {
        if(course==null || index<0 || index>=cards.size()) { return false; }
        holeIndex=index; save(); return true;
    }
    function updateScore(field,delta) {
        var old=card(); var c=[old[0],old[1],old[2],old[3]];
        if((field==1 || field==2) && c[0]==null) { return false; }
        if(field==0 && c[0]==null) { c[0]=delta>0 ? 1 : null; }
        else if(field==3) { c[3]=(c[3]+delta+4)%4; }
        else { var v=c[field]+delta; if(v>=0 && v<=(field==0 ? 30 : 10)) { c[field]=v; } }
        if(c[0]==0) { c[0]=null; }
        if(c[0]!=null && c[0]<c[1]+c[2]) { return false; }
        cards[holeIndex]=c; save(); return true;
    }
    function total() { var n=0; for(var i=0;i<cards.size();i+=1) { if(cards[i][0]!=null) { n+=cards[i][0]; } } return n; }
    function played() { var n=0; for(var i=0;i<cards.size();i+=1) { if(cards[i][0]!=null) { n+=1; } } return n; }
    function points() {
        var n=0;
        for(var i=0;i<cards.size();i+=1) {
            if(cards[i][0]==null) { continue; }
            var h=course["holes"][i]; var received=GolfRules.strokesForHole(handicap,h["strokeIndex"],cards.size());
            var p=GolfRules.stableford(cards[i][0],h["par"],received); if(p==null) { return null; } n+=p;
        }
        return n;
    }
    function startShot(point) {
        if(!log.start(holeIndex,clubId(),point,Time.now().value())) { return false; }
        save(); return true;
    }
    function finishShot(point) {
        var shot=log.finish(point,Time.now().value()); if(shot!=null) { save(); } return shot;
    }
    function cancelShot() { if(!log.cancel()) { return false; } save(); return true; }
    function addManualShot(club,putt) {
        var shot=log.addManual(holeIndex,club,putt ? 2 : 1,Time.now().value()); if(shot!=null) { save(); } return shot;
    }
    function setShotClub(id,club) { if(!log.changeClub(id,club)) { return false; } save(); return true; }
    function removeShot(id) { if(!log.remove(id)) { return false; } save(); return true; }
    function retryCleanup() {
        if(!storageReady) { return false; }
        for(var c=0;c<cleanupPending.size();c+=1) {
            if((roundId!=null && cleanupPending[c].equals(roundId)) || (saved!=null && saved["roundId"]!=null && cleanupPending[c].equals(saved["roundId"]))) { storageError="Opprydding peker på aktiv runde"; return false; }
            for(var h=0;h<historyNew.size();h+=1) { if(cleanupPending[c].equals(historyNew[h]["id"])) { storageError="Opprydding peker på beholdt historikk"; return false; } }
        }
        var remaining=[];
        for(var i=0;i<cleanupPending.size();i+=1) { try { store.remove(cleanupPending[i]); } catch(e) { remaining.add(cleanupPending[i]); } }
        try { store.set("history-v2",{"entries"=>historyNew,"cleanup"=>remaining}); cleanupPending=remaining; }
        catch(e) { storageError="Opprydding må prøves igjen"; return false; }
        if(remaining.size()==0 && !dirty) { storageError=null; }
        return remaining.size()==0;
    }
    function archive() {
        if(!storageReady || course==null) { return false; }
        if(log.pending!=null) { storageError="Fullfør eller avbryt slagmålingen først"; return false; }
        if(cleanupPending.size()>0 && !retryCleanup()) { storageError="Tidligere opprydding må fullføres"; return false; }
        if(!save()) { return false; }
        var summary={"id"=>roundId,"course"=>course["name"],"strokes"=>total(),"played"=>played(),"started"=>started};
        var full={"version"=>2,"roundId"=>roundId,"course"=>course["name"],"started"=>started,"holeCount"=>cards.size(),"cards"=>cards,"shotLog"=>log.serialize(),"clubs"=>clubs};
        var next=[summary]; var obsolete=[];
        for(var i=0;i<historyNew.size();i+=1) {
            if(historyNew[i]["id"].equals(roundId)) { continue; }
            if(next.size()<10) { next.add(historyNew[i]); } else { obsolete.add(historyNew[i]["id"]); }
        }
        var phase=0;
        try {
            // Each complete round has its own value (the SDK limits each value to 32 KB).
            store.set(roundId,full); phase=1;
            store.set("history-v2",{"entries"=>next,"cleanup"=>obsolete}); phase=2;
            historyNew=next; cleanupPending=obsolete; refreshHistory();
            store.remove("active-v1");
            saved=null; course=null; roundId=null; log=new GolfShotLog(); dirty=false; storageError=null;
        } catch(e) { storageError=phase==2 ? "Historikk lagret; aktiv runde ble beholdt" : "Arkivering feilet; aktiv runde beholdt"; return false; }
        if(cleanupPending.size()>0 && !retryCleanup()) { storageError="Runde lagret; opprydding gjenstår"; }
        return true;
    }
    function archivedLog(id) {
        try {
            for(var i=0;i<historyNew.size();i+=1) {
                if(!historyNew[i]["id"].equals(id)) { continue; }
                var full=store.get(id); var parsed=new GolfShotLog();
                if(!(full instanceof Dictionary) || full["version"]!=2 || !(full["roundId"] instanceof String) || !full["roundId"].equals(id) || full["started"]!=historyNew[i]["started"] || !(full["course"] instanceof String) || !full["course"].equals(historyNew[i]["course"]) || !(full["holeCount"] instanceof Number) || full["holeCount"]<1 || full["holeCount"]>36 || !parsed.load(full["shotLog"],full["holeCount"])) { storageError="Rundens slaglogg kan ikke leses"; return null; }
                if(full["clubs"] instanceof Array) {
                    for(var b=0;b<full["clubs"].size() && b<GolfClubs.IDS.size();b+=1) {
                        var club=full["clubs"][b];
                        if(club instanceof Array && club.size()==2 && club[0] instanceof String) { parsed.savedClubNames[GolfClubs.IDS[b]]=club[0]; }
                    }
                }
                return parsed;
            }
            for(var j=0;j<historyLegacy.size();j+=1) {
                if(!id.equals("legacy-"+j)) { continue; }
                var old=historyLegacy[j]; var legacy=new GolfShotLog();
                if(old["cards"] instanceof Array && old["cards"].size()>0 && old["cards"].size()<=36 && legacy.loadLegacy(old["shots"],null,null,0,old["started"],old["cards"].size())) { return legacy; }
                storageError="Eldre runde har ingen lesbar slaglogg"; return null;
            }
        } catch(e) { storageError="Kunne ikke lese slagloggen"; }
        if(storageError==null) { storageError="Runden finnes ikke i historikken"; }
        return null;
    }
    function discard() {
        if(!storageReady) { return false; }
        try { store.remove("active-v1"); saved=null; course=null; roundId=null; log=new GolfShotLog(); dirty=false; storageError=cleanupPending.size()>0 ? "Opprydding gjenstår" : null; return true; }
        catch(e) { storageError="Runden ble ikke forkastet"; return false; }
    }
    function distanceLabel(meters) { return meters==null ? "--" : (yards ? meters*1.0936133 : meters).format("%.0f"); }
}
