import Toybox.WatchUi;
import Toybox.Lang;

class GolfMenuHarness extends GolfRenderHarness {
    var view; var menus; var notice=null;
    function initialize() {
        GolfRenderHarness.initialize(); view=new GolfView(self); menus=new GolfMenus(self);
    }
    function showPage(page) { menus.closeAll(); view.page=page; }
    function notify(text) { notice=text; }
}
(:test)
function nativeMenuItemsAndCallbacksUseStableCommands(logger) {
    var app=new GolfMenuHarness(); var ok=false;
    try {
        // A newly allocated string must route by value, not literal identity.
        var menu=app.menus.open(("x"+"courses").substring(1,8),null);
        var item=menu.getItem(0);
        if(item==null || item.getId()["value"]!=0) { throw new Lang.InvalidValueException("Course menu empty"); }
        new GolfMenuDelegate(app.menus).onSelect(item);
        if(app.state.course==null || !app.view.page.equals("hole") || app.menus.depth!=0) { throw new Lang.InvalidValueException("Course selection failed"); }
        menu=app.menus.open(("x"+"main").substring(1,5),null);
        item=menu.getItem(0);
        new GolfMenuDelegate(app.menus).onSelect(item);
        ok=app.view.page.equals("green") && app.menus.depth==0;
        app.menus.open("settings",null); new GolfMenuDelegate(app.menus).onBack();
        ok=ok && app.menus.depth==0;
    } catch(e) { logger.error(e.getErrorMessage()); }
    app.menus.closeAll(); return ok;
}
