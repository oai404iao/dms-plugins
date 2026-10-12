pragma Singleton
import QtQuick

QtObject {
    property var sink: null
    readonly property int wheelVolumeStep: 5

    function displayName(node) {
        return node && node.name ? node.name : "";
    }

    function getMaxVolumePercent(node) {
        return 100;
    }

    function setDefaultSinkByName(name) {
    }

    function playVolumeChangeSoundIfEnabled() {
    }
}
