import QtQuick

Item {
    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    width: parent.width
    implicitHeight: 40
    height: implicitHeight
}
