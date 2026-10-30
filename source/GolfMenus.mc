import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Menu entries bind named actions to stable payloads, never display text or list ordinals.
class GolfMenus {
    var app; var depth=0;
    function initialize(a) { app=a; }
    function add(menu,label,sub,action,value) {
        menu.addItem(new WatchUi.MenuItem(label,sub,{"action"=>action,"value"=>value},null));
    }
    function back() { if(depth>0) { WatchUi.popView(WatchUi.SLIDE_DOWN); depth-=1; } }
    function closeAll() { while(depth>0) { WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); depth-=1; } }
    function problem(text) { closeAll(); app.notify(text); }
    function logFor(context) { return context!=null && context["archive"]!=null ? app.view.archivedLog : app.state.log; }
    function shotLabel(log,shot) {
        if(shot["kind"]==2) { return "Putt · avstand ukjent"; }
        return shot["distance"]==null ? "Manuelt · avstand ukjent" : app.state.distanceLabel(shot["distance"])+(app.state.yards ? " yd målt" : " m målt");
    }
    function open(route,context) {
        var s=app.state;
        var titles={"main"=>s.course==null ? "Golf App" : "Golfmeny","courses"=>"Velg bane","holes"=>"Bytt hull","settings"=>"Innstillinger","clubs"=>"Mine køller","clubPick"=>"Velg kølle","shots"=>"Slag","shotList"=>"Slaghistorikk","shotActions"=>"Rediger slag","deleteShot"=>"Slette slag?","cancelShot"=>"Avbryt måling?","clubStats"=>"Køllestatistikk","finish"=>"Avslutt runde","discard"=>"Forkast runde?","history"=>"Lagrede runder","hazards"=>"Kartobjekter"};
        if(!titles.hasKey(route)) { problem("Menyen kunne ikke åpnes"); return null; }
        var menu=new WatchUi.Menu2({:title=>titles[route]});
        if(route.equals("main")) {
            if(s.course==null) {
                if(s.saved!=null) { add(menu,"Fortsett runde",null,"resume",null); }
                add(menu,"Ny runde",null,"menu",["courses",null]);
                add(menu,"Mine køller",null,"menu",["clubs",null]);
                add(menu,"Rundehistorikk",s.history.size()+" runder","menu",["history",null]);
                if(s.cleanupPending.size()>0) { add(menu,"Prøv opprydding igjen",null,"cleanup",null); }
            } else {
                add(menu,"Vis green",null,"page","green"); add(menu,"Vis kart",null,"page","map");
                add(menu,"Kølleforslag","Egen carry og avstand","page","caddie");
                add(menu,"Bytt hull","Hull "+s.hole()["number"],"menu",["holes",null]);
                add(menu,"Scorekort",null,"page","score");
                add(menu,"Mål slag",s.log.pending==null ? "Manuell måling" : "Måling pågår","page","shot");
                add(menu,"Slaghistorikk",s.log.entries.size()+" registreringer","menu",["shots",null]);
                add(menu,"Køllestatistikk","Denne runden","menu",["clubStats",null]);
                add(menu,"Søketimer","3 minutter","search",null);
                add(menu,"Rundeinformasjon",null,"page","summary");
                if(s.dirty) { add(menu,"Prøv lagring på nytt","Endringer er ikke lagret","save",null); }
                add(menu,"Avslutt runde",null,"menu",["finish",null]);
            }
            add(menu,"Innstillinger",null,"menu",["settings",null]); add(menu,"Om appen",null,"page","about");
        } else if(route.equals("courses")) {
            for(var i=0;i<s.catalog.size();i+=1) { var c=s.catalog[i]; add(menu,c["name"],c["holes"].size()+" hull · OSM","course",i); }
        } else if(route.equals("holes")) {
            for(var h=0;h<s.cards.size();h+=1) { var hole=s.course["holes"][h]; add(menu,"Hull "+hole["number"],"Par "+hole["par"]+(h==s.holeIndex ? " · valgt" : ""),"hole",h); }
        } else if(route.equals("shots")) {
            if(s.log.pending==null) { add(menu,"Start nytt slag","Velg kølle ved ballen","pick",{"mode"=>"start"}); }
            else {
                add(menu,"Fortsett måling","Fra hull "+(s.log.pending["hole"]+1),"page","shot");
                add(menu,"Fullfør ved ballen",s.clubName(s.log.pending["clubId"]),"finishShot",null);
                add(menu,"Bytt kølle for målingen",null,"pick",{"mode"=>"pending"});
                add(menu,"Avbryt målingen",null,"menu",["cancelShot",null]);
            }
            add(menu,"Velg kølle for neste slag",s.clubName(s.clubId()),"pick",{"mode"=>"pick"});
            add(menu,"Legg til glemt slag","Uten GPS-avstand","pick",{"mode"=>"manual"});
            add(menu,"Registrer en putt","Avstand ukjent · score føres separat","putt",null);
            add(menu,"Slag på dette hullet",s.log.forHole(s.holeIndex).size()+" registreringer","menu",["shotList",{"hole"=>s.holeIndex,"archive"=>null}]);
            add(menu,"Alle slag i runden",s.log.entries.size()+" registreringer","menu",["shotList",{"hole"=>null,"archive"=>null}]);
            if(s.dirty) { add(menu,"Prøv lagring på nytt",null,"save",null); }
        } else if(route.equals("clubPick")) {
            for(var order=0;order<GolfClubs.DISPLAY_ORDER.size();order+=1) {
                var j=GolfClubs.DISPLAY_ORDER[order];
                var club=GolfClubs.IDS[j]; var sub=s.clubs[j][1]==null ? "Carry ikke satt" : s.clubs[j][1]+" m carry";
                if(s.clubId()!=null && s.clubId().equals(club)) { sub="Valgt · "+sub; }
                add(menu,s.clubs[j][0],sub,"picked",{"mode"=>context["mode"],"id"=>context["id"],"club"=>club});
            }
            add(menu,"Ukjent kølle",null,"picked",{"mode"=>context["mode"],"id"=>context["id"],"club"=>null});
        } else if(route.equals("shotList")) {
            var log=logFor(context);
            if(log==null) { problem("Slagloggen er utilgjengelig"); return null; }
            var rows=log.forHole(context==null ? null : context["hole"]);
            if(rows.size()==0) { add(menu,"Ingen registrerte slag","Slagloggen og scorekortet er separate","noop",null); }
            for(var k=0;k<rows.size();k+=1) {
                var shot=rows[k]; var name=log==s.log ? s.clubName(shot["clubId"]) : log.clubName(shot["clubId"]);
                add(menu,"Hull "+(shot["hole"]+1)+" · "+name,shotLabel(log,shot),"viewShot",{"id"=>shot["id"],"archive"=>context==null ? null : context["archive"]});
            }
        } else if(route.equals("shotActions")) {
            var current=s.log.find(context);
            if(current==null) { problem("Slaget finnes ikke lenger"); return null; }
            add(menu,"Bytt kølle",s.clubName(current["clubId"]),"pick",{"mode"=>"edit","id"=>context});
            add(menu,"Slett registreringen","Scorekortet endres ikke","menu",["deleteShot",context]);
            add(menu,"Til scorekort",null,"page","score");
        } else if(route.equals("deleteShot")) {
            add(menu,"Ja, slett dette slaget","Scorekortet endres ikke","removeShot",context);
            add(menu,"Behold registreringen",null,"back",null);
        } else if(route.equals("cancelShot")) {
            add(menu,"Ja, avbryt målingen","Ingen slagregistrering slettes","cancelShot",null);
            add(menu,"Fortsett å måle",null,"back",null);
        } else if(route.equals("clubs") || route.equals("clubStats")) {
            for(var bagOrder=0;bagOrder<GolfClubs.DISPLAY_ORDER.size();bagOrder+=1) {
                var b=GolfClubs.DISPLAY_ORDER[bagOrder];
                var id=GolfClubs.IDS[b];
                if(route.equals("clubs")) { add(menu,s.clubs[b][0],s.clubs[b][1]==null ? "Carry ikke satt" : s.clubs[b][1]+" m carry","editCarry",id); }
                else { var stats=s.log.stats(id); add(menu,s.clubs[b][0],stats["count"]+" slag · "+stats["measured"]+" målt","clubStats",id); }
            }
        } else if(route.equals("settings")) {
            add(menu,"Enhet",s.yards ? "Yards" : "Meter","units",null);
            add(menu,"Store tall",s.bigNumbers ? "På" : "Av","bigNumbers",null);
            add(menu,"Turneringsmodus",s.tournament ? "På" : "Av","tournament",null);
            add(menu,"Spillehandicap",s.handicap.toString(),"page","handicap");
            add(menu,"Mine køller",null,"menu",["clubs",null]);
            if(s.course!=null) {
                add(menu,"Vind og vær",null,"page","weather"); add(menu,"Retning til flagg","Nord opp","page","pointer");
                add(menu,"Kartlagte hindringer",null,"menu",["hazards",null]); add(menu,"Nullstill flagg",null,"resetPin",null);
            }
        } else if(route.equals("history")) {
            if(s.history.size()==0) { add(menu,"Ingen lagrede runder",null,"noop",null); }
            for(var r=0;r<s.history.size();r+=1) { var item=s.history[r]; add(menu,item["course"],item["strokes"]+" slag / "+item["played"]+" hull","archive",item["id"]); }
        } else if(route.equals("hazards")) {
            var hazards=app.view.geometry()["hazards"]; var player=app.livePosition();
            add(menu,"Nærliggende kartobjekter","Ikke komplett hinderoversikt","noop",null);
            for(var z=0;z<hazards.size();z+=1) { var distance=player==null ? null : Geo.boundaryDistance(player,hazards[z]["points"]); add(menu,hazards[z]["type"].equals("bunker") ? "Bunker" : "Vann",s.distanceLabel(distance)+(s.yards ? " yd" : " m")+" til kartgrense","noop",null); }
        } else if(route.equals("finish")) {
            if(s.log.pending!=null) { add(menu,"Måling pågår","Fullfør eller avbryt først","page","shot"); }
            else { add(menu,"Lagre og avslutt",s.played()+" hull / "+s.total()+" slag","archiveRound",null); }
            add(menu,"Fortsett å spille",null,"page","hole"); add(menu,"Forkast runde",null,"menu",["discard",null]);
        } else if(route.equals("discard")) {
            add(menu,"Ja, forkast aktiv runde","Lagret historikk beholdes","discard",null); add(menu,"Behold runden",null,"back",null);
        }
        WatchUi.pushView(menu,new GolfMenuDelegate(self),WatchUi.SLIDE_UP); depth+=1; return menu;
    }
    function openShot(id,archive) {
        var v=app.view; v.selectedShotId=id; v.readOnlyRound=archive;
        v.returnMenu="shotList"; v.returnContext={"hole"=>null,"archive"=>archive};
        app.showPage("shotDetail");
    }
    function picked(value) {
        var s=app.state; var mode=value["mode"]; var id=value["club"];
        if(mode.equals("edit")) { if(!s.setShotClub(value["id"],id)) { problem("Slaget finnes ikke lenger"); return; } openShot(value["id"],null); }
        else if(mode.equals("pending")) {
            if(!s.log.changePendingClub(id)) { problem("Ingen måling pågår"); return; }
            s.save(); app.showPage("shot");
        } else if(mode.equals("manual")) {
            var shot=s.addManualShot(id,false);
            if(shot==null) { problem("Slagloggen er full"); return; }
            openShot(shot["id"],null); app.notify(s.dirty ? "Registrert; lagring feilet" : "Glemt slag registrert");
        } else {
            s.shotClub=GolfClubs.index(id); s.save(); app.showPage("shot");
            if(mode.equals("start")) { app.startMeasurement(); }
        }
    }
    function handle(action,value,item) {
        var s=app.state;
        if(action.equals("noop")) { return; }
        if(action.equals("back")) { back(); return; }
        if(action.equals("menu")) { open(value[0],value[1]); return; }
        if(action.equals("pick")) { open("clubPick",value); return; }
        if(action.equals("picked")) { picked(value); return; }
        if(action.equals("viewShot")) { openShot(value["id"],value["archive"]); return; }
        if(action.equals("archive")) {
            var archived=s.archivedLog(value); if(archived==null) { problem(s.storageError); return; }
            app.view.archivedLog=archived; app.view.readOnlyRound=value;
            open("shotList",{"hole"=>null,"archive"=>value}); return;
        }
        if(action.equals("units") || action.equals("tournament") || action.equals("bigNumbers")) {
            if(action.equals("units")) { s.yards=!s.yards; } else if(action.equals("bigNumbers")) { s.bigNumbers=!s.bigNumbers; } else { s.tournament=!s.tournament; }
            if(!s.saveSettings()) { problem("Innstillingen ble ikke lagret"); }
            else { item.setSubLabel(action.equals("units") ? (s.yards ? "Yards" : "Meter") : ((action.equals("bigNumbers") ? s.bigNumbers : s.tournament) ? "På" : "Av")); WatchUi.requestUpdate(); }
            return;
        }
        if(action.equals("page")) { app.showPage(value); return; }
        if(action.equals("resume")) { s.resume(); app.showPage("hole"); }
        else if(action.equals("course")) {
            if(s.saved!=null) { problem("Fortsett eller avslutt lagret runde"); return; }
            if(s.begin(value)) { app.showPage("hole"); } else { problem(s.storageError==null ? "Banen kunne ikke åpnes" : s.storageError); }
        } else if(action.equals("hole")) { s.selectHole(value); app.showPage("hole"); }
        else if(action.equals("finishShot")) { app.completeMeasurement(); }
        else if(action.equals("cancelShot")) { if(!s.cancelShot()) { problem("Ingen måling pågår"); return; } app.showPage("shot"); app.notify(s.dirty ? "Avbrutt; lagring feilet" : "Slagmåling avbrutt"); }
        else if(action.equals("removeShot")) {
            if(!s.removeShot(value)) { problem("Slaget finnes ikke lenger"); return; }
            app.showPage("shot"); app.notify(s.dirty ? "Fjernet; lagring feilet" : "Slagregistrering slettet");
        } else if(action.equals("putt")) {
            var putt=s.addManualShot("putter",true); if(putt==null) { problem("Slagloggen er full"); return; }
            openShot(putt["id"],null); app.notify(s.dirty ? "Registrert; lagring feilet" : "Putt registrert · score separat");
        } else if(action.equals("editCarry")) { app.view.editClub=GolfClubs.index(value); app.view.returnMenu="clubs"; app.view.returnContext=null; app.showPage("club"); }
        else if(action.equals("clubStats")) { app.view.statsClubId=value; app.view.returnMenu="clubStats"; app.view.returnContext=null; app.showPage("clubStats"); }
        else if(action.equals("search")) { s.searchUntil=Time.now().value()+180; app.showPage("search"); }
        else if(action.equals("resetPin")) { s.pins[s.holeIndex]=null; s.save(); app.showPage("hole"); }
        else if(action.equals("archiveRound")) { if(s.archive()) { app.showPage("home"); app.notify("Runde lagret"); } else { problem(s.storageError); } }
        else if(action.equals("discard")) { if(s.discard()) { app.showPage("home"); } else { problem(s.storageError); } }
        else if(action.equals("save")) { app.showPage("shot"); app.notify(s.save() ? "Endringer lagret" : "Lagring feilet igjen"); }
        else if(action.equals("cleanup")) { problem(s.retryCleanup() ? "Opprydding fullført" : "Opprydding gjenstår"); }
    }
}

class GolfMenuDelegate extends WatchUi.Menu2InputDelegate {
    var owner;
    function initialize(controller) { Menu2InputDelegate.initialize(); owner=controller; }
    function onBack() as Void { owner.back(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var command=item.getId() as Dictionary;
        owner.handle(command["action"],command["value"],item);
    }
}
