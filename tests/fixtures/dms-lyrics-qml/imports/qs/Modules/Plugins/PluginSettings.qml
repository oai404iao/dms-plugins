import QtQuick
import qs.Common

Column {
    id: root
    property string pluginId: ""
    property var pluginService: null
    spacing: Theme.spacingM

    function loadValue(key, fallback) {
        return SettingsData.pluginSettings[pluginId]?.[key] ?? fallback;
    }

    function saveValue(key, value) {
        if (!pluginService || loadValue(key, undefined) === value)
            return;
        var all = Object.assign({}, SettingsData.pluginSettings);
        all[pluginId] = Object.assign({}, all[pluginId]);
        all[pluginId][key] = value;
        SettingsData.pluginSettings = all;
    }

    function reloadChildValues() {
        for (var i = 0; i < children.length; i++) {
            if (children[i].loadValue)
                children[i].loadValue();
        }
    }

    onPluginServiceChanged: reloadChildValues()
    Connections {
        target: SettingsData
        function onPluginSettingsChanged() {
            root.reloadChildValues();
        }
    }
}
