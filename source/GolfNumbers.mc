import Toybox.Lang;
module GolfNumbers {
    function abs(a) { return a<0 ? -a : a; }
    function min(a,b) { return a<b ? a : b; }
    function max(a,b) { return a>b ? a : b; }
    function isNumeric(a) { return a instanceof Number || a instanceof Float || a instanceof Double || a instanceof Long; }
}
