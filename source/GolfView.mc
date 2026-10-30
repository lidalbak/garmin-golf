import Toybox.Graphics;
import Toybox.Math;
import Toybox.Time;
import Toybox.System;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Weather;

class GolfView extends WatchUi.View {
    const WHITE=0xF1F3EA;
    const MUTED=0xA6AD9F;
    const YELLOW=0xFFDE00;
    const GREEN=0x9DC35A;
    var app; var page="home"; var editClub=0;
    var selectedShotId=null; var readOnlyRound=null; var archivedLog=null;
    var statsClubId="driver"; var returnMenu=null; var returnContext=null;
    var geo=null; var geoCourse=-1; var geoHole=-1;
    var transform=null;
    var touchTarget=null;
    var zoom=1.0;
    var panX=0.0; var panY=0.0;
    var cameraPage="";
    var mapBitmap=null; var mapCacheKey=null;
    var dragLast=null; var flagDrag=false; var lastDragAt=-1000;

    function resetCamera() { zoom=1.0; panX=0.0; panY=0.0; mapBitmap=null; mapCacheKey=null; }
    function onHide() { mapBitmap=null; mapCacheKey=null; }
    function changeZoom(factor) { zoom=GolfNumbers.max(1.0,GolfNumbers.min(8.0,zoom*factor)); if(zoom==1.0) { panX=0; panY=0; } WatchUi.requestUpdate(); }


    function initialize(a) { View.initialize(); app=a; }
    function geometry() {
        var s=app.state;
        if(geo==null || geoCourse!=s.courseIndex || geoHole!=s.holeIndex) {
            geo=Courses.geometry(s.courseIndex,s.holeIndex); geoCourse=s.courseIndex; geoHole=s.holeIndex; touchTarget=null; resetCamera();
        }
        return geo;
    }
    function text(dc,x,y,font,value,color) {
        dc.setColor(color,Graphics.COLOR_TRANSPARENT);
        dc.drawText(x,y,font,value,Graphics.TEXT_JUSTIFY_CENTER);
    }
    function line(dc,y) { dc.setColor(0x33382E,Graphics.COLOR_TRANSPARENT); dc.drawLine(68,y,348,y); }
    function title(dc,value) { text(dc,208,35,Graphics.FONT_SMALL,value,WHITE); line(dc,78); }
    function footer(dc,value) { text(dc,208,355,Graphics.FONT_XTINY,value,MUTED); }
    function button(dc,x,y,w,label) {
        dc.setColor(0x203727,Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(x,y,w,45,12);
        text(dc,x+w/2,y+5,Graphics.FONT_SMALL,label,WHITE);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(WHITE,Graphics.COLOR_BLACK); dc.clear(); transform=null;
        var s=app.state;
        if(!cameraPage.equals(page)) { resetCamera(); cameraPage=page; }
        if(page.equals("home") || (s.course==null && !page.equals("club") && !page.equals("handicap") && !page.equals("about") && !(page.equals("shotDetail") && readOnlyRound!=null))) { home(dc); }
        else if(page.equals("hole")) { hole(dc); }
        else if(page.equals("map") || page.equals("green")) { mapPage(dc); }
        else if(page.equals("score")) { score(dc); }
        else if(page.equals("summary")) { summary(dc); }
        else if(page.equals("shot")) { shotMeasurement(dc); }
        else if(page.equals("shotDetail")) { shotDetail(dc); }
        else if(page.equals("clubStats")) { clubStats(dc); }
        else if(page.equals("caddie")) { caddie(dc); }
        else if(page.equals("weather")) { weather(dc); }
        else if(page.equals("pointer")) { pointer(dc); }
        else if(page.equals("search")) { search(dc); }
        else if(page.equals("club")) { edit(dc,false); }
        else if(page.equals("handicap")) { edit(dc,true); }
        else if(page.equals("about")) { about(dc); }
        if(s.storageError==null && app.message!=null && Time.now().value()<app.messageUntil) {
            dc.setColor(0x233B2A,Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(40,285,336,65,12);
            text(dc,208,296,Graphics.FONT_XTINY,app.wrapMessage(app.message),WHITE);
        }
        if(s.storageError!=null) {
            dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(55,335,306,58,10);
            text(dc,208,338,Graphics.FONT_XTINY,app.wrapMessage(s.storageError),0xFF8B74);
        }
    }
    function home(dc) {
        title(dc,"GOLF APP");
        text(dc,208,105,Graphics.FONT_MEDIUM,"Spill golf",YELLOW);
        text(dc,208,150,Graphics.FONT_SMALL,"Bogstad · Bærum",WHITE);
        text(dc,208,190,Graphics.FONT_XTINY,"36 hull · åpne kartdata",MUTED);
        button(dc,88,244,240,app.state.saved==null ? "Velg bane" : "Fortsett runde");
        footer(dc,"Knapp / trykk: meny");
    }
    function hole(dc) {
        var s=app.state; var h=s.hole(); var p=app.livePosition(); var target=s.target();
        if(!s.bigNumbers) {
            drawMap(dc,MapLayout.mainViewport,MapLayout.mainFit,false);
            maskMainMap(dc);
        }
        title(dc,"#"+h["number"]+"  Par "+(h["par"]==null ? "?" : h["par"].toString()));
        var middle=p==null ? null : Geo.distance(p,target);
        var edges=p==null ? null : Geo.greenEdges(p,target,geometry()["green"]);
        var distanceX=s.bigNumbers ? 208 : 112;
        text(dc,distanceX,98,s.bigNumbers ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MEDIUM,s.distanceLabel(edges==null ? null : edges[1]),WHITE);
        text(dc,distanceX,167,Graphics.FONT_NUMBER_HOT,s.distanceLabel(middle),YELLOW);
        text(dc,distanceX,253,s.bigNumbers ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MEDIUM,s.distanceLabel(edges==null ? null : edges[0]),WHITE);
        text(dc,distanceX,313,Graphics.FONT_XTINY,s.yards ? "yards" : "meter",MUTED);
        var status=p==null ? "Søker GPS" : s.pins[s.holeIndex]==null ? "OSM-mål" : "Manuelt flagg";
        text(dc,s.bigNumbers ? 208 : 118,350,Graphics.FONT_XTINY,status,MUTED);
    }
    function mapPage(dc) {
        drawMap(dc,MapLayout.detailViewport,MapLayout.detailFit,page.equals("green"));
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0,0,416,78); dc.fillRectangle(0,354,416,62);
        title(dc,page.equals("green") ? "Green · dra flagget" : "Hull "+app.state.hole()["number"]+" · banekart");
        dc.setColor(0x253423,Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(77,315,64,36,10); dc.fillRoundedRectangle(169,315,78,36,10); dc.fillRoundedRectangle(275,315,64,36,10);
        text(dc,109,315,Graphics.FONT_SMALL,"−",WHITE); text(dc,208,317,Graphics.FONT_XTINY,zoom.format("%.1f")+"×",WHITE); text(dc,307,315,Graphics.FONT_SMALL,"+",WHITE);
        if(touchTarget!=null && page.equals("map")) {
            var p=app.livePosition();
            var a=p==null ? "--" : app.state.distanceLabel(Geo.distance(p,touchTarget));
            footer(dc,a+" / "+app.state.distanceLabel(Geo.distance(touchTarget,app.state.target()))+" til green");
        } else { footer(dc,page.equals("green") ? "Dra flagg · dra kart · zoom +/−" : "Dra kart · © OpenStreetMap"); }
    }
    function local(p,origin,cs,sn) {
        var a=Geo.project(p,origin); return [a[0]*cs-a[1]*sn,a[0]*sn+a[1]*cs];
    }
    function screen(p) {
        var t=transform; var a=local(p,t[0],t[1],t[2]);
        return [(t[6]+(a[0]-t[3])*t[5]).toNumber(),(t[7]+(t[4]-a[1])*t[5]).toNumber()];
    }
    function fromScreen(x,y) {
        var t=transform; var xx=(x-t[6])/t[5]+t[3]; var yy=t[4]-(y-t[7])/t[5];
        return Geo.unproject([xx*t[1]+yy*t[2],-xx*t[2]+yy*t[1]],t[0]);
    }
    function polygon(dc,ring,color) {
        if(ring==null || ring.size()<3) { return; }
        var points=[]; for(var i=0;i<ring.size();i+=1) { points.add(screen(ring[i])); }
        dc.setColor(color,Graphics.COLOR_TRANSPARENT); dc.fillPolygon(points);
    }
    function flag(dc,where) {
        dc.setColor(WHITE,Graphics.COLOR_TRANSPARENT); dc.setPenWidth(2); dc.drawLine(where[0],where[1],where[0],where[1]-22);
        dc.setColor(0xFF6250,Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[where[0],where[1]-22],[where[0]+13,where[1]-16],[where[0],where[1]-12]]);
    }
    function maskMainMap(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_TRANSPARENT); dc.setPenWidth(1);
        for(var y=78;y<416;y+=1) {
            var span=MapLayout.mainSpan(y);
            dc.drawLine(208,y,span[0].toNumber(),y);
            if(span[1]<416) { dc.drawLine(span[1].toNumber(),y,415,y); }
        }
    }
    function drawMap(dc,viewport,fit,greenOnly) {
        var x=viewport[0]; var y=viewport[1]; var w=viewport[2]; var h=viewport[3];
        var s=app.state; var data=geometry(); var hole=s.hole();
        var origin=hole["tee"]; var angle=Geo.bearing(origin,hole["center"])*Geo.RAD;
        var cs=Math.cos(angle); var sn=Math.sin(angle);
        var extent=greenOnly ? data["green"] : data["path"];
        var minx=null; var maxx=null; var miny=null; var maxy=null;
        for(var j=0;j<extent.size();j+=1) {
            var q=local(extent[j],origin,cs,sn);
            if(minx==null || q[0]<minx) { minx=q[0]; } if(maxx==null || q[0]>maxx) { maxx=q[0]; }
            if(miny==null || q[1]<miny) { miny=q[1]; } if(maxy==null || q[1]>maxy) { maxy=q[1]; }
        }
        if(!greenOnly) {
            for(var k=0;k<data["green"].size();k+=1) {
                var g=local(data["green"][k],origin,cs,sn);
                minx=GolfNumbers.min(minx,g[0]); maxx=GolfNumbers.max(maxx,g[0]); miny=GolfNumbers.min(miny,g[1]); maxy=GolfNumbers.max(maxy,g[1]);
            }
        }
        var padding=greenOnly ? 6.0 : 18.0;
        var scale=GolfNumbers.min(fit[2]/(maxx-minx+padding*2),fit[3]/(maxy-miny+padding*2));
        var interactive=page.equals("map") || page.equals("green");
        if(interactive) { scale*=zoom; }
        var cx=(minx+maxx)/2.0; var cy=(miny+maxy)/2.0;
        transform=[origin,cs,sn,cx-fit[2]/(2.0*scale),cy+fit[3]/(2.0*scale),scale,fit[0]+(interactive ? panX : 0),fit[1]+(interactive ? panY : 0)];
        dc.setClip(x,y,w,h);
        var key=s.courseIndex+":"+s.holeIndex+":"+page+":"+w+":"+h+":"+zoom+":"+panX+":"+panY;
        if(mapCacheKey==null || !mapCacheKey.equals(key)) {
            mapBitmap=null;
            var sx=transform[6]; var sy=transform[7];
            try {
                mapBitmap=Graphics.createBufferedBitmap({:width=>w,:height=>h}).get() as Graphics.BufferedBitmap;
                transform[6]-=x; transform[7]-=y;
                drawScene(mapBitmap.getDc(),w,h);
                mapCacheKey=key;
            } catch(e) { mapBitmap=null; mapCacheKey=null; }
            transform[6]=sx; transform[7]=sy;
        }
        if(mapBitmap!=null) { dc.drawBitmap(x,y,mapBitmap); }
        else { drawScene(dc,w,h); }
        if(!greenOnly) {
            dc.setColor(0xD1DBAA,Graphics.COLOR_TRANSPARENT); dc.setPenWidth(1);
            for(var a=1;a<data["path"].size();a+=1) { var f=screen(data["path"][a-1]); var t=screen(data["path"][a]); dc.drawLine(f[0],f[1],t[0],t[1]); }
            dc.setPenWidth(1);
            var tee=screen(origin); dc.setColor(WHITE,Graphics.COLOR_TRANSPARENT); dc.fillCircle(tee[0],tee[1],4);
            var carry=s.clubs[0][1];
            if(carry!=null && !s.tournament) { dc.drawArc(tee[0],tee[1],carry*scale,Graphics.ARC_CLOCKWISE,25,155); }
            var end=screen(hole["center"]); var dist=Geo.distance(origin,hole["center"]);
            var colors=[0xFF6250,WHITE,0x54A4FF,YELLOW];
            for(var m=0;m<4;m+=1) {
                var meters=100.0+m*50.0;
                if(meters<dist) { var ratio=meters/dist; var lx=end[0]+(tee[0]-end[0])*ratio; var ly=end[1]+(tee[1]-end[1])*ratio; dc.setColor(colors[m],Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx,ly,3); }
            }
        }
        polygon(dc,data["green"],GREEN);
        flag(dc,screen(s.target()));
        var p=app.livePosition();
        if(p!=null) { var pp=screen(p); dc.setColor(0x68C3FF,Graphics.COLOR_TRANSPARENT); dc.fillCircle(pp[0],pp[1],5); }
        if(touchTarget!=null && !greenOnly) { var tt=screen(touchTarget); dc.setColor(YELLOW,Graphics.COLOR_TRANSPARENT); dc.drawCircle(tt[0],tt[1],7); }
        dc.clearClip(); dc.setPenWidth(1);
    }
    function drawScene(dc as Graphics.Dc,w,h) as Void {
        dc.setColor(MapStyle.background,MapStyle.background); dc.clear();
        var scene=geometry()["scene"];
        var colors=MapStyle.colors();
        var surfaces=scene["surfaces"];
        for(var i=0;i<surfaces.size();i+=1) { polygon(dc,surfaces[i]["points"],colors[surfaces[i]["kind"]]); }
        var symbols=scene["canopySymbols"];
        for(var j=0;j<symbols.size();j+=1) { tree(dc,symbols[j],j); }
        var actual=scene["trees"];
        for(var k=0;k<actual.size();k+=1) { tree(dc,actual[k],k+2); }
    }
    function tree(dc as Graphics.Dc,p,variant) as Void {
        var xy=screen(p); var r=GolfNumbers.max(2.0,GolfNumbers.min(9.0,4.5*transform[5]));
        dc.setColor(MapStyle.treeShadow,Graphics.COLOR_TRANSPARENT); dc.fillCircle(xy[0]+r*0.4,xy[1]+r*0.5,r);
        dc.setColor(MapStyle.treeCanopy[variant%3],Graphics.COLOR_TRANSPARENT); dc.fillCircle(xy[0],xy[1],r);
        dc.setColor(MapStyle.treeHighlight[variant%2],Graphics.COLOR_TRANSPARENT); dc.fillCircle(xy[0]-r*0.25,xy[1]-r*0.3,r*0.6);
    }
    function score(dc) {
        var s=app.state; var c=s.card();
        title(dc,"Score · hull "+s.hole()["number"]);
        var labels=["Slag totalt","Putter","Straffeslag","Fairway"];
        var values=[c[0]==null ? "--" : c[0].toString(),c[1].toString(),c[2].toString(),["--","Venstre","Treff","Høyre"][c[3]]];
        for(var i=0;i<4;i+=1) {
            var y=92+i*56;
            text(dc,145,y,Graphics.FONT_SMALL,labels[i],MUTED);
            text(dc,283,y,Graphics.FONT_SMALL,values[i],i==0 ? YELLOW : WHITE);
        }
        footer(dc,"Trykk venstre − / høyre +");
    }
    function summary(dc) {
        var s=app.state; title(dc,"Runde · "+s.course["name"]);
        text(dc,208,98,Graphics.FONT_NUMBER_HOT,s.total().toString(),YELLOW);
        text(dc,208,187,Graphics.FONT_SMALL,s.played().toString()+" / "+s.cards.size().toString()+" hull",WHITE);
        var points=s.points(); text(dc,208,231,Graphics.FONT_SMALL,"Stableford: "+(points==null ? "ukjent indeks" : points.toString()),WHITE);
        var elapsed=Time.now().value()-s.started;
        text(dc,208,274,Graphics.FONT_SMALL,(elapsed/3600).format("%d")+":"+((elapsed%3600)/60).format("%02d")+"  ·  "+s.log.entries.size().toString()+" registreringer",MUTED);
        footer(dc,"Knapp: rundemeny");
    }
    function shotMeasurement(dc) {
        var s=app.state; var pending=s.log.pending; var player=app.livePosition();
        title(dc,pending==null ? "Mål slag" : "Måler fra hull "+(pending["hole"]+1));
        var club=pending==null ? s.clubId() : pending["clubId"];
        text(dc,208,99,Graphics.FONT_MEDIUM,s.clubName(club),WHITE);
        var distance=pending==null || player==null ? null : Geo.distance(pending["start"],player);
        text(dc,208,150,Graphics.FONT_NUMBER_HOT,s.distanceLabel(distance),YELLOW);
        text(dc,208,239,Graphics.FONT_XTINY,pending==null ? "Start ved ballen før slaget" : player==null ? "Venter på fersk GPS" : (s.yards ? "yards" : "meter")+" · avslutt ved ballen",MUTED);
        button(dc,78,274,260,pending==null ? "Start nytt slag" : "Fullfør slag");
        text(dc,208,328,Graphics.FONT_XTINY,"Kølle · historikk · avbryt",WHITE);
        footer(dc,"Manuell måling · score separat");
    }
    function viewedShot() {
        var log=readOnlyRound==null ? app.state.log : archivedLog;
        return log==null ? null : log.find(selectedShotId);
    }
    function shotDetail(dc) {
        var s=app.state; var shot=viewedShot();
        if(shot==null) { title(dc,"Slag utilgjengelig"); footer(dc,"Tilbake: slaghistorikk"); return; }
        title(dc,"Slag · hull "+(shot["hole"]+1));
        text(dc,208,99,Graphics.FONT_MEDIUM,readOnlyRound==null ? s.clubName(shot["clubId"]) : archivedLog.clubName(shot["clubId"]),WHITE);
        text(dc,208,148,Graphics.FONT_NUMBER_HOT,s.distanceLabel(shot["distance"]),YELLOW);
        var kind=shot["kind"];
        text(dc,208,238,Graphics.FONT_XTINY,kind==0 ? (s.yards ? "yards" : "meter")+" · GPS inkl. rull" : kind==2 ? "Putt · avstand ikke målt" : "Glemt slag · avstand ikke målt",MUTED);
        if(readOnlyRound==null) {
            button(dc,58,288,142,"Rediger"); button(dc,216,288,142,s.log.pending==null ? "Nytt slag" : "Til måling");
        }
        footer(dc,readOnlyRound==null ? "Slagloggen endrer ikke scoren" : "Lagret runde · kun visning");
    }
    function clubStats(dc) {
        var s=app.state; var stats=s.log.stats(statsClubId); var index=GolfClubs.index(statsClubId);
        title(dc,s.clubName(statsClubId));
        text(dc,208,103,Graphics.FONT_MEDIUM,stats["count"]+" registrerte slag",WHITE);
        text(dc,208,160,Graphics.FONT_SMALL,"Snitt: "+s.distanceLabel(stats["average"])+(s.yards ? " yd" : " m"),YELLOW);
        text(dc,208,202,Graphics.FONT_SMALL,"Lengst: "+s.distanceLabel(stats["longest"])+(s.yards ? " yd" : " m"),WHITE);
        text(dc,208,250,Graphics.FONT_XTINY,stats["measured"]+" GPS-målinger · inkl. rull",MUTED);
        text(dc,208,291,Graphics.FONT_XTINY,"Egen carry: "+s.distanceLabel(s.clubs[index][1])+(s.yards ? " yd" : " m"),MUTED);
        footer(dc,"Denne runden · carry endres ikke");
    }
    function caddie(dc) {
        var s=app.state; title(dc,"Kølleforslag");
        if(s.tournament) { text(dc,208,157,Graphics.FONT_SMALL,"Av i turneringsmodus",WHITE); return; }
        var p=app.livePosition(); var distance=p==null ? null : Geo.distance(p,s.target());
        var club=GolfRules.recommend(s.clubs,distance);
        text(dc,208,108,Graphics.FONT_NUMBER_MEDIUM,s.distanceLabel(distance),YELLOW);
        text(dc,208,189,Graphics.FONT_MEDIUM,club==null ? "Ingen forslag" : club,WHITE);
        text(dc,208,243,Graphics.FONT_XTINY,"Kun avstand og egen carry",MUTED);
        text(dc,208,278,Graphics.FONT_XTINY,"Vind / høyde er ikke korrigert",MUTED);
        footer(dc,"Legg inn carry i Mine køller");
    }
    function weather(dc) {
        title(dc,"Vind og vær");
        var conditions=Weather.getCurrentConditions();
        if(conditions==null) { text(dc,208,150,Graphics.FONT_SMALL,"Ingen værobservasjon",WHITE); footer(dc,"Synkroniser Garmin Connect"); return; }
        var age=conditions.observationTime==null ? null : Time.now().value()-conditions.observationTime.value();
        if(age==null || age<0 || age>3600) { text(dc,208,150,Graphics.FONT_SMALL,"Observasjonen er for gammel",WHITE); footer(dc,"Trenger data under 60 min gamle"); return; }
        var speed=conditions.windSpeed; var bearing=conditions.windBearing;
        text(dc,208,107,Graphics.FONT_NUMBER_MEDIUM,speed==null ? "--" : speed.format("%.1f"),YELLOW);
        text(dc,208,175,Graphics.FONT_SMALL,"m/s  ·  "+(bearing==null ? "--" : bearing.toString())+"°",WHITE);
        text(dc,208,222,Graphics.FONT_SMALL,conditions.temperature==null ? "-- °C" : conditions.temperature.format("%.0f")+" °C",WHITE);
        text(dc,208,270,Graphics.FONT_XTINY,(age/60).format("%d")+" min gammel observasjon",MUTED);
        footer(dc,"Værstasjon · ikke målt på klokken");
    }
    function pointer(dc) {
        title(dc,"Retning · nord opp");
        if(app.state.tournament) { text(dc,208,157,Graphics.FONT_SMALL,"Av i turneringsmodus",WHITE); return; }
        var player=app.livePosition();
        if(player==null) { text(dc,208,150,Graphics.FONT_SMALL,"Venter på GPS",WHITE); return; }
        var heading=Geo.bearing(player,app.state.target()); var a=heading*Geo.RAD;
        var x=208+85*Math.sin(a); var y=200-85*Math.cos(a);
        dc.setColor(YELLOW,Graphics.COLOR_TRANSPARENT); dc.setPenWidth(5); dc.drawLine(208,200,x,y); dc.fillCircle(x,y,8); dc.setPenWidth(1);
        text(dc,208,87,Graphics.FONT_XTINY,"N",MUTED);
        text(dc,208,289,Graphics.FONT_SMALL,heading.format("%.0f")+"° sann peiling",WHITE);
        footer(dc,"Kartretning · følger ikke håndleddet");
    }
    function search(dc) {
        title(dc,"Søk etter ball");
        var left=app.state.searchUntil==null ? 0 : GolfNumbers.max(0,app.state.searchUntil-Time.now().value());
        text(dc,208,140,Graphics.FONT_NUMBER_HOT,(left/60).format("%d")+":"+(left%60).format("%02d"),left==0 ? 0xFF6250 : YELLOW);
        text(dc,208,256,Graphics.FONT_SMALL,left==0 ? "3 minutter har gått" : "Trykk for å starte på nytt",WHITE);
        footer(dc,"Tilbake: hullvisning");
    }
    function edit(dc,isHandicap) {
        var s=app.state;
        title(dc,isHandicap ? "Spillehandicap" : s.clubs[editClub][0]+" · carry (m)");
        var value=isHandicap ? s.handicap : s.clubs[editClub][1];
        text(dc,208,135,Graphics.FONT_NUMBER_HOT,value==null ? "--" : value.toString(),YELLOW);
        button(dc,70,245,100,"−"); button(dc,246,245,100,"+");
        footer(dc,isHandicap ? "Handicap for valgt runde" : "Egen normal carry · 5 m trinn");
    }
    function about(dc) {
        title(dc,"Golf App · Venu 2");
        text(dc,208,104,Graphics.FONT_SMALL,"S72-inspirert prototype",WHITE);
        text(dc,208,153,Graphics.FONT_XTINY,"© OpenStreetMap contributors",MUTED);
        text(dc,208,187,Graphics.FONT_XTINY,"Kartdata: ODbL · 16.10.2026",MUTED);
        text(dc,208,230,Graphics.FONT_XTINY,"Kartmål er ikke dagens flagg.",WHITE);
        text(dc,208,267,Graphics.FONT_XTINY,"Ingen greenhelling / svingmåling",MUTED);
        text(dc,208,300,Graphics.FONT_XTINY,"openstreetmap.org/copyright",MUTED);
        footer(dc,"Tilbake: hovedvisning");
    }
}

class GolfDelegate extends WatchUi.BehaviorDelegate {
    var app;
    function initialize(a) { BehaviorDelegate.initialize(); app=a; }
    function onSelect() {
        if(app.view.page.equals("shot")) { app.shotAction(); }
        else if(app.view.page.equals("shotDetail") && app.view.readOnlyRound==null) { app.menus.open("shotActions",app.view.selectedShotId); }
        else { app.menu("main"); }
        return true;
    }
    function onMenu() { app.menu("main"); return true; }
    function onBack() {
        if(app.view.page.equals("home")) { return false; }
        var v=app.view;
        if((v.page.equals("club") || v.page.equals("clubStats") || v.page.equals("shotDetail")) && v.returnMenu!=null) {
            var route=v.returnMenu; var context=v.returnContext; v.returnMenu=null; v.returnContext=null;
            app.showPage(app.state.course==null ? "home" : "hole"); app.menus.open(route,context); return true;
        }
        app.showPage(app.state.course==null || app.view.page.equals("hole") ? "home" : "hole"); return true;
    }
    function onNextPage() { return move(1); }
    function onPreviousPage() { return move(-1); }
    function move(delta) {
        if(app.state.course!=null && (app.view.page.equals("hole") || app.view.page.equals("score"))) { app.state.changeHole(delta); app.showPage("hole"); return true; } return false;
    }
    function onSwipe(event) {
        if(app.view.page.equals("map") || app.view.page.equals("green")) { return true; }
        if(app.state.course==null || (!app.view.page.equals("hole") && !app.view.page.equals("score"))) { return false; }
        if(event.getDirection()==WatchUi.SWIPE_LEFT) { return move(1); }
        if(event.getDirection()==WatchUi.SWIPE_RIGHT) { return move(-1); }
        app.showPage(app.view.page.equals("score") ? "hole" : "score"); return true;
    }
    function onDrag(event as WatchUi.DragEvent) as Boolean {
        var v=app.view; var s=app.state;
        if((!v.page.equals("map") && !v.page.equals("green")) || v.transform==null) { return false; }
        var xy=event.getCoordinates(); var kind=event.getType();
        if(kind==WatchUi.DRAG_TYPE_START) {
            if(xy[1]<78 || xy[1]>=315) { return true; }
            v.dragLast=xy;
            var flag=v.screen(s.target()); var dx=xy[0]-flag[0]; var dy=xy[1]-flag[1];
            v.flagDrag=v.page.equals("green") && dx*dx+dy*dy<1600;
        } else if(v.dragLast!=null) {
            if(v.flagDrag) {
                var coord=v.fromScreen(xy[0],xy[1]);
                if(Geo.contains(coord,v.geometry()["green"])) { s.pins[s.holeIndex]=coord; }
            } else {
                v.panX=GolfNumbers.max(-600.0,GolfNumbers.min(600.0,v.panX+xy[0]-v.dragLast[0]));
                v.panY=GolfNumbers.max(-600.0,GolfNumbers.min(600.0,v.panY+xy[1]-v.dragLast[1]));
            }
            v.dragLast=xy;
        }
        v.lastDragAt=System.getTimer();
        if(kind==WatchUi.DRAG_TYPE_STOP) { if(v.flagDrag) { s.save(); } v.dragLast=null; v.flagDrag=false; }
        WatchUi.requestUpdate(); return true;
    }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var xy=event.getCoordinates(); var x=xy[0]; var y=xy[1]; var v=app.view; var s=app.state;
        if(System.getTimer()-v.lastDragAt<250) { return true; }
        if(v.page.equals("home")) {
            if(x>=88 && x<=328 && y>=244 && y<=289) {
                if(s.saved!=null) { s.resume(); app.showPage("hole"); }
                else { app.menu("courses"); }
            } else { app.menu("main"); } return true;
        }
        if(v.page.equals("hole")) { if(MapLayout.mainContains(x,y)) { app.showPage("map"); } else { app.menu("main"); } return true; }
        if(v.page.equals("map") || v.page.equals("green")) {
            if(y>=315 && y<=351 && x>=65 && x<=351) {
                if(x<151) { v.changeZoom(1.0/1.5); }
                else if(x>265) { v.changeZoom(1.5); }
                else { v.resetCamera(); WatchUi.requestUpdate(); }
                return true;
            }
            if(v.transform!=null && y>=78 && y<315) {
                var coord=v.fromScreen(x,y);
                if(v.page.equals("green")) {
                    if(Geo.contains(coord,v.geometry()["green"])) { s.pins[s.holeIndex]=coord; s.save(); app.notify("Manuelt flagg satt"); }
                    else { app.notify("Velg et punkt inne på greenen"); }
                } else { v.touchTarget=coord; WatchUi.requestUpdate(); }
            } return true;
        }
        if(v.page.equals("shot")) {
            if(y>=274 && y<=319) { app.shotAction(); }
            else if(y>=90 && y<=140) { app.menus.open("clubPick",{"mode"=>s.log.pending==null ? "pick" : "pending"}); }
            else { app.menus.open("shots",null); }
            return true;
        }
        if(v.page.equals("shotDetail")) {
            if(v.readOnlyRound==null && y>=288 && y<=333) {
                if(x<208) { app.menus.open("shotActions",v.selectedShotId); }
                else { app.showPage("shot"); if(s.log.pending==null) { app.shotAction(); } }
            }
            return true;
        }
        if(v.page.equals("score")) {
            var row=((y-92)/56).toNumber();
            if(y>=92 && row>=0 && row<4) { if(!s.updateScore(row,x<208 ? -1 : 1)) { app.notify("Totalen må dekke putter og straff"); } WatchUi.requestUpdate(); }
            return true;
        }
        if(v.page.equals("search")) { s.searchUntil=Time.now().value()+180; WatchUi.requestUpdate(); return true; }
        if(v.page.equals("club") || v.page.equals("handicap")) {
            if(y<235 || y>305) { return true; }
            var delta=x<208 ? -1 : 1;
            if(v.page.equals("handicap")) { s.handicap=GolfNumbers.max(-10,GolfNumbers.min(54,s.handicap+delta)); }
            else { var current=s.clubs[v.editClub][1]; s.clubs[v.editClub][1]=current==null ? 100 : GolfNumbers.max(5,GolfNumbers.min(400,current+5*delta)); }
            s.saveSettings(); WatchUi.requestUpdate(); return true;
        }
        app.menu("main"); return true;
    }
}
