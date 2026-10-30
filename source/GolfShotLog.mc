import Toybox.Lang;

// Owns identity, interpretation, measurement attribution and compact storage.
// A measured GPS displacement is total distance, not a carry measurement.
class GolfShotLog {
    const CAPACITY=100;
    var entries=[];
    var pending=null;
    var nextId=1;
    var savedClubNames={};

    function initialize() {}
    function coordinate(p) {
        return p instanceof Array && p.size()==2 && GolfNumbers.isNumeric(p[0]) && GolfNumbers.isNumeric(p[1]) && p[0]>=-90 && p[0]<=90 && p[1]>=-180 && p[1]<=180;
    }
    function copyPoint(p) { return p==null ? null : [p[0],p[1]]; }
    function load(data,holeCount) {
        if(!(data instanceof Array) || data.size()!=3 || !(data[0] instanceof Number) || data[0]<1 || !(data[2] instanceof Array) || data[2].size()>CAPACITY) { return false; }
        var parsed=[]; var ids={};
        for(var i=0;i<data[2].size();i+=1) {
            var row=data[2][i];
            if(!(row instanceof Array) || row.size()!=8 || !(row[0] instanceof Number) || row[0]<1 || row[0]>=data[0] || ids.hasKey(row[0]) || !(row[1] instanceof Number) || row[1]<0 || row[1]>=holeCount || !GolfClubs.valid(row[2]) || !(row[3] instanceof Number) || row[3]<0 || row[3]>2 || (row[4]!=null && (!GolfNumbers.isNumeric(row[4]) || !(row[4]>=0))) || (row[5]!=null && !coordinate(row[5])) || (row[6]!=null && !coordinate(row[6])) || (row[7]!=null && !(row[7] instanceof Number))) { return false; }
            if(row[4]!=null && row[4]>Geo.EARTH*3.141592653589793) { return false; }
            if(row[3]==0 && (row[4]==null || row[5]==null || row[6]==null)) { return false; }
            ids[row[0]]=true;
            parsed.add({"id"=>row[0],"hole"=>row[1],"clubId"=>row[2],"kind"=>row[3],"distance"=>row[4],"start"=>copyPoint(row[5]),"end"=>copyPoint(row[6]),"at"=>row[7]});
        }
        var active=null;
        if(data[1]!=null) {
            var p=data[1];
            if(!(p instanceof Array) || p.size()!=4 || !(p[0] instanceof Number) || p[0]<0 || p[0]>=holeCount || !GolfClubs.valid(p[1]) || !coordinate(p[2]) || !(p[3] instanceof Number)) { return false; }
            active={"hole"=>p[0],"clubId"=>p[1],"start"=>copyPoint(p[2]),"at"=>p[3]};
        }
        if(parsed.size()+(active==null ? 0 : 1)>CAPACITY) { return false; }
        entries=parsed; pending=active; nextId=data[0]; return true;
    }
    function loadLegacy(rows,start,club,hole,at,holeCount) {
        if(!(rows instanceof Array) || rows.size()>CAPACITY) { return false; }
        var encoded=[];
        for(var i=0;i<rows.size();i+=1) {
            var r=rows[i];
            if(!(r instanceof Array) || r.size()!=5 || !(r[1] instanceof Number) || r[1]<0 || r[1]>=10) { return false; }
            encoded.add([i+1,r[0],GolfClubs.IDS[r[1]],0,r[2],r[3],r[4],null]);
        }
        if(club!=null && (!(club instanceof Number) || club<0 || club>=10)) { return false; }
        var active=start==null ? null : [hole,club==null ? null : GolfClubs.IDS[club],start,at];
        return load([rows.size()+1,active,encoded],holeCount);
    }
    function serialize() {
        var rows=[];
        for(var i=0;i<entries.size();i+=1) {
            var s=entries[i]; rows.add([s["id"],s["hole"],s["clubId"],s["kind"],s["distance"],copyPoint(s["start"]),copyPoint(s["end"]),s["at"]]);
        }
        var active=pending==null ? null : [pending["hole"],pending["clubId"],copyPoint(pending["start"]),pending["at"]];
        return [nextId,active,rows];
    }
    function find(id) {
        for(var i=0;i<entries.size();i+=1) { if(entries[i]["id"]==id) { return entries[i]; } }
        return null;
    }
    function latest() { return entries.size()==0 ? null : entries[entries.size()-1]; }
    function clubName(id) {
        if(id==null) { return "Ukjent kølle"; }
        return savedClubNames.hasKey(id) ? savedClubNames[id] : id;
    }
    function forHole(hole) {
        var found=[];
        for(var i=entries.size()-1;i>=0;i-=1) { if(hole==null || entries[i]["hole"]==hole) { found.add(entries[i]); } }
        return found;
    }
    function start(hole,club,point,at) {
        if(pending!=null || entries.size()>=CAPACITY || !coordinate(point) || !GolfClubs.valid(club)) { return false; }
        pending={"hole"=>hole,"clubId"=>club,"start"=>copyPoint(point),"at"=>at}; return true;
    }
    function finish(point,at) {
        if(pending==null || entries.size()>=CAPACITY || !coordinate(point)) { return null; }
        var shot={"id"=>nextId,"hole"=>pending["hole"],"clubId"=>pending["clubId"],"kind"=>0,"distance"=>Geo.distance(pending["start"],point),"start"=>copyPoint(pending["start"]),"end"=>copyPoint(point),"at"=>at};
        entries.add(shot); nextId+=1; pending=null; return shot;
    }
    function addManual(hole,club,kind,at) {
        if(entries.size()+(pending==null ? 0 : 1)>=CAPACITY || !GolfClubs.valid(club) || (kind!=1 && kind!=2)) { return null; }
        var shot={"id"=>nextId,"hole"=>hole,"clubId"=>club,"kind"=>kind,"distance"=>null,"start"=>null,"end"=>null,"at"=>at};
        entries.add(shot); nextId+=1; return shot;
    }
    function changeClub(id,club) {
        var s=find(id); if(s==null || !GolfClubs.valid(club)) { return false; }
        s["clubId"]=club; return true;
    }
    function changePendingClub(club) {
        if(pending==null || !GolfClubs.valid(club)) { return false; }
        pending["clubId"]=club; return true;
    }
    function cancel() { if(pending==null) { return false; } pending=null; return true; }
    function remove(id) {
        var remaining=[]; var found=false;
        for(var i=0;i<entries.size();i+=1) { if(entries[i]["id"]==id) { found=true; } else { remaining.add(entries[i]); } }
        if(found) { entries=remaining; } return found;
    }
    function stats(club) {
        var count=0; var measured=0; var total=0.0; var longest=null;
        for(var i=0;i<entries.size();i+=1) {
            var s=entries[i]; if(s["clubId"]==null || !s["clubId"].equals(club)) { continue; }
            count+=1;
            if(s["kind"]==0 && s["distance"]!=null) {
                measured+=1; total+=s["distance"];
                if(longest==null || s["distance"]>longest) { longest=s["distance"]; }
            }
        }
        return {"count"=>count,"measured"=>measured,"average"=>measured==0 ? null : total/measured,"longest"=>longest};
    }
}
