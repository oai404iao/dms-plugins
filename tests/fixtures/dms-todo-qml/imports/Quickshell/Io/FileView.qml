import QtQuick

QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool blockWrites: false
    property bool atomicWrites: false
    property bool printErrors: false
    property string contents: ""
    property int reloadCount: 0
    property int writeCount: 0
    signal loaded()
    signal loadFailed(int error)
    signal fileChanged()
    function text() { return contents; }
    function setText(value) { contents = value; writeCount++; }
    function reload() { reloadCount++; }
    function inject(value) { contents = value; loaded(); }
    Component.onCompleted: TestIo.file = this
}
