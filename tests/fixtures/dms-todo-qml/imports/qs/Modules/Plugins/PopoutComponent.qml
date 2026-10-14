import QtQuick
import qs.Common

Item {
    id: root
    default property alias contentData: content.data
    property string headerText: ""
    property string detailsText: ""
    property bool showCloseButton: false
    width: 400
    height: 600
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }
    Column {
        x: Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingXS
        Text {
            text: root.headerText
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
        }
        Text {
            text: root.detailsText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
    Item {
        id: content
        y: 70
        width: parent.width
        height: parent.height - y
    }
}
