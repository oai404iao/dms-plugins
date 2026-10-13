import QtQuick
import qs.Common
import qs.Services

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
        var all = Object.assign({}, SettingsData.pluginSettings);
        all[pluginId] = next;
        SettingsData.pluginSettings = all;
    }
}
