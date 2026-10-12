import QtQuick
import QtQuick.Window

Item {
    id: root
    property string layerNamespace: ""
    property Component content: null
    property Component overlayContent: null
    property real popupWidth: 400
    property real popupHeight: 300
    property real triggerWidth: 40
    property string triggerSection: ""
    property var screen: null
    property bool shouldBeVisible: false
    property bool hoverDismissSuspended: false
    readonly property var window: Window.window
    readonly property var backgroundWindow: window
    readonly property real alignedX: 0
    readonly property real alignedY: 0
    readonly property real alignedWidth: popupWidth
    readonly property real alignedHeight: popupHeight
    readonly property int effectiveBarPosition: 0
    readonly property alias transientSurfaceTracker: tracker
    readonly property alias contentLoader: body
    readonly property alias overlayLoader: overlay
    signal backgroundClicked

    function open() {
        shouldBeVisible = true;
    }
    function close() {
        tracker.closeAll();
        shouldBeVisible = false;
    }

    TransientSurfaceTracker {
        id: tracker
    }
    Loader {
        id: body
        width: root.popupWidth
        height: root.popupHeight
        active: root.shouldBeVisible
        sourceComponent: root.content
    }
    Loader {
        id: overlay
        anchors.fill: parent
        z: 2
        active: root.shouldBeVisible
        sourceComponent: root.overlayContent
    }
}
