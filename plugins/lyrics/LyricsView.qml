pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

ListView {
    id: root

    property int activeIndex: -1
    property bool showTranslation: true

    clip: true
    currentIndex: activeIndex
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: height / 2 - 20
    preferredHighlightEnd: height / 2 + 20
    highlightMoveDuration: 300
    highlightMoveVelocity: -1

    delegate: Item {
        id: lyricDelegate

        required property int index
        required property string text
        required property string translation

        width: root.width
        height: text === "" ? 0 : lyricLines.implicitHeight + 16
        visible: text !== ""
        readonly property bool isActive: index === root.activeIndex

        Column {
            id: lyricLines

            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: lyricDelegate.text
                textFormat: Text.PlainText
                width: parent.width
                font.pixelSize: lyricDelegate.isActive ? Theme.fontSizeMedium + 2 : Theme.fontSizeMedium
                font.weight: lyricDelegate.isActive ? Font.Bold : Font.Normal
                color: lyricDelegate.isActive ? Theme.primary : Theme.surfaceText
                opacity: lyricDelegate.isActive ? 1.0 : 0.4
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap

                Behavior on color { ColorAnimation { duration: 250 } }
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on font.pixelSize { NumberAnimation { duration: 250 } }
            }

            StyledText {
                text: lyricDelegate.translation
                textFormat: Text.PlainText
                visible: root.showTranslation && text !== ""
                width: parent.width
                font.pixelSize: Theme.fontSizeSmall
                color: lyricDelegate.isActive ? Theme.surfaceText : Theme.surfaceVariantText
                opacity: lyricDelegate.isActive ? 1.0 : 0.4
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap

                Behavior on opacity { NumberAnimation { duration: 250 } }
            }
        }
    }
}
