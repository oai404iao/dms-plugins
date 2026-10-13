pragma Singleton
import QtQuick

QtObject {
    property string lastWarning: ""
    function showWarning(text) { lastWarning = text; }
}
