import QtQuick

// Models the dropdown lifecycle only; no native PopupWindow or focus grab.
Item {
    id: root
    property string text: ""
    property string description: ""
    property string currentValue: ""
    property var options: []
    property var transientSurfaceTracker: null
    property bool menuOpen: false
    readonly property bool isLifecycleMock: true
    signal valueChanged(string value)
    implicitHeight: 60
    height: implicitHeight

    onMenuOpenChanged: transientSurfaceTracker?.setActive(root, menuOpen, null)
    Component.onDestruction: transientSurfaceTracker?.unregister(root)

    function closeDropdownMenu() {
        menuOpen = false;
    }

    function select(value) {
        valueChanged(value);
        closeDropdownMenu();
    }

    Connections {
        target: root.transientSurfaceTracker
        function onCloseRequested() {
            root.closeDropdownMenu();
        }
    }
}
