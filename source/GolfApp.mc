import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class GolfApp extends Application.AppBase {
    var state;
    var menus;
    var view;
    var position=null;
    var fixTime=null;
    var timer;
    var message=null;
    var messageUntil=0;

    function initialize() { AppBase.initialize(); }
    function onStart(args) {
        state=new GolfState(new GolfDeviceStore()); view=new GolfView(self); menus=new GolfMenus(self);
        timer=new Timer.Timer(); timer.start(method(:tick),1000,true);
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS,method(:onPosition));
    }
    function onStop(args) {
        Position.enableLocationEvents(Position.LOCATION_DISABLE,method(:onPosition));
        if(timer!=null) { timer.stop(); }
        state.save();
    }
    function onPosition(info as Position.Info) as Void {
        // Never present old or poor-quality positions as a current location.
        if(info.position!=null && (info.accuracy==Position.QUALITY_GOOD || info.accuracy==Position.QUALITY_USABLE) && info.when!=null) {
            var age=Time.now().value()-info.when.value();
            if(age>=-5 && age<=15) { position=info.position.toDegrees(); fixTime=info.when.value(); }
        } else { position=null; fixTime=null; }
        WatchUi.requestUpdate();
    }
    function livePosition() {
        if(position==null || fixTime==null || Time.now().value()-fixTime>15) { return null; }
        return position;
    }
    function tick() as Void {
        if(state.consumeSearchAlarm(Time.now().value())) {
            notify("Søketid: 3 minutter har gått");
            if(Attention has :vibrate) { Attention.vibrate([new Attention.VibeProfile(80,700),new Attention.VibeProfile(0,250),new Attention.VibeProfile(80,700)]); }
        }
        WatchUi.requestUpdate();
    }
    function notify(text) { message=text; messageUntil=Time.now().value()+5; WatchUi.requestUpdate(); }
    function wrapMessage(text) {
        if(text.length()<=30) { return text; }
        var at=30;
        while(at>15 && !text.substring(at,at+1).equals(" ")) { at-=1; }
        if(at==15) { at=30; }
        var tail=text.substring(at,text.length());
        if(tail.substring(0,1).equals(" ")) { tail=tail.substring(1,tail.length()); }
        return text.substring(0,at)+"\n"+tail;
    }
    function getInitialView() { return [view,new GolfDelegate(self)]; }

    function menu(kind) { menus.open(kind,null); }
    function showPage(page) { menus.closeAll(); view.page=page; WatchUi.requestUpdate(); }
    function startMeasurement() {
        var p=livePosition();
        if(p==null) { notify("Venter på fersk GPS-posisjon"); return; }
        if(!state.startShot(p)) { notify(state.log.pending!=null ? "En måling pågår allerede" : "Slagloggen er full"); return; }
        notify(state.dirty ? "Måler; lagring feilet" : "Slagmåling startet");
    }
    function completeMeasurement() {
        showPage("shot");
        var p=livePosition();
        if(p==null) { notify("Venter på fersk GPS-posisjon"); return; }
        var shot=state.finishShot(p);
        if(shot==null) { notify("Slaget kunne ikke registreres"); return; }
        menus.openShot(shot["id"],null);
        notify(state.dirty ? "Målt; lagring feilet" : "Slag lagret · score separat");
    }
    function shotAction() {
        if(state.log.pending!=null) { completeMeasurement(); }
        else { menus.open("clubPick",{"mode"=>"start"}); }
    }
}
