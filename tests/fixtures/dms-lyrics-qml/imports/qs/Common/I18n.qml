pragma Singleton
import QtQuick

QtObject {
    property bool isRtl: false
    property var pluginTranslations: ({})

    function tr(term) {
        return term;
    }

    function trFor(pluginId, term) {
        return pluginTranslations[pluginId]?.[term]?.[term] || tr(term);
    }
}
