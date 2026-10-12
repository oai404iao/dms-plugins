import QtQuick

Item {
    property var targetScreen: null
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0
    property real contentOffsetY: 0
    property string section: ""
    property int barPosition: 0
    property int resetCount: 0
    property int shortcutCount: 0
    implicitHeight: 410
    signal showVolumeDropdown(point pos, var screen, bool rightEdge, var player, var players)
    signal showAudioDevicesDropdown(point pos, var screen, bool rightEdge)
    signal showPlayersDropdown(point pos, var screen, bool rightEdge, var player, var players)
    signal showLyricsDropdown(point pos, var screen, bool rightEdge)
    signal hideDropdowns
    signal dropdownButtonExited
    signal dropdownButtonEntered
    function resetDropdownStates() {
        resetCount++;
    }
    function handleKeyEvent(event) {
        shortcutCount++;
        event.accepted = true;
        return true;
    }
}
