import QtQuick

Item {
    required property string settingKey
    required property string label
    property string description: ""
    property real minimum: 0
    property real maximum: 100
    property real defaultValue: 0
    width: parent.width
    implicitHeight: 40
    height: implicitHeight
}
