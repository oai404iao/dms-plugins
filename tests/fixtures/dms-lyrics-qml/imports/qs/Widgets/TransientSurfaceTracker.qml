import QtQuick

QtObject {
    id: root
    property var entries: []
    readonly property bool active: entries.length > 0
    property int closeCount: 0
    signal closeRequested

    function setActive(owner, active, focusWindow) {
        var next = entries.filter(entry => entry !== owner);
        if (active)
            next.push(owner);
        entries = next;
    }

    function unregister(owner) {
        setActive(owner, false, null);
    }

    function closeAll() {
        if (!active)
            return;
        closeCount++;
        closeRequested();
        entries = [];
    }
}
