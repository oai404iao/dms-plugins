import QtQuick
import qs.Common

Column {
    property string pluginId: ""
    property var pluginService: null
    property var values: ({})
    spacing: Theme.spacingM
    function loadValue(key, fallback) {
        return values[key] === undefined ? fallback : values[key];
    }
    function saveValue(key, value) {
        var next = Object.assign({}, values);
        next[key] = value;
        values = next;
    }
}
