pragma Singleton
import QtQuick

QtObject {
    property bool isRtl: false
    property string localeTag: "en_US"
    property var pluginTranslations: ({})
    function trFor(pluginId, term) {
        return pluginTranslations[pluginId]?.[term]?.[term] || term;
    }
    function locale() { return Qt.locale(localeTag); }
}
