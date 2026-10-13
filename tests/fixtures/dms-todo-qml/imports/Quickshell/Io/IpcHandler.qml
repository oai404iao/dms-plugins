import QtQuick

QtObject {
    property string target: ""
    Component.onCompleted: TestIo.ipc = this
}
