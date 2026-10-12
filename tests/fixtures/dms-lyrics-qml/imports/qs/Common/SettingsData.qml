pragma Singleton
import QtQuick

QtObject {
    property var pluginSettings: ({})
    property bool weatherEnabled: true
    property bool showWeekNumber: false

    function visibleDashTabIds() {
        return ["overview", "media", "wallpaper", "weather", "settings"];
    }
}
