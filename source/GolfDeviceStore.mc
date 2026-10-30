import Toybox.Application;

// The only adapter touching device storage; domain tests can supply a fake store.
class GolfDeviceStore {
    function initialize() {}
    function get(key) { return Application.Storage.getValue(key); }
    function set(key,value) { Application.Storage.setValue(key,value); }
    function remove(key) { Application.Storage.deleteValue(key); }
}
