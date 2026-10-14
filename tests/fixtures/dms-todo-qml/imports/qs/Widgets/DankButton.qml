import QtQuick
import QtQuick.Controls
import qs.Common

// Render the host button's public color/icon contract, retaining native Qt
// Controls focus and activation semantics rather than loading real host code.
Button {
    id: control
    property int buttonHeight: 40
    horizontalPadding: 12
    property int iconSize: 20
    property string iconName: ""
    property color backgroundColor: "#cc77ff"
    property color textColor: "#ffffff"
    height: buttonHeight
    implicitWidth: Math.max(32, contentItem.implicitWidth + horizontalPadding * 2)
    background: Rectangle {
        radius: Theme.cornerRadius
        color: control.backgroundColor
        border.width: control.activeFocus ? 2 : 0
        border.color: Theme.primary
        opacity: control.enabled ? 1 : 0.45
    }
    contentItem: Row {
        spacing: control.text && control.iconName ? 4 : 0
        opacity: control.enabled ? 1 : 0.45
        DankIcon {
            visible: !!control.iconName
            name: control.iconName
            size: control.iconSize
            color: control.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: !!control.text
            text: control.text
            color: control.textColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
