import Toybox.Lang;

// Stable identifiers survive menu ordering and display-name changes.
module GolfClubs {
    const IDS=["driver","wood3","hybrid","iron5","iron6","iron7","iron8","iron9","pw","sw","iron4","gw","lw","putter"];
    const DISPLAY_ORDER=[0,1,2,10,3,4,5,6,7,8,11,9,12,13];
    function defaults() {
        return [["Driver",null],["3 wood",null],["Hybrid",null],["5 jern",null],["6 jern",null],["7 jern",null],["8 jern",null],["9 jern",null],["PW",null],["SW",null],["4 jern",null],["GW",null],["LW",null],["Putter",null]];
    }
    function index(id) {
        if(id==null) { return null; }
        for(var i=0;i<IDS.size();i+=1) { if(IDS[i].equals(id)) { return i; } }
        return null;
    }
    function valid(id) { return id==null || (id instanceof String && index(id)!=null); }
}
