import QtQuick

Item {
    property int currentIndex: 0
    property real spacing: 0
    property bool equalWidthTabs: false
    property bool enableArrowNavigation: false
    property var nextFocusTarget: null
    property var model: []
    signal tabClicked(int index)
    signal actionTriggered(int index)
    function snapIndicator() {}
}
