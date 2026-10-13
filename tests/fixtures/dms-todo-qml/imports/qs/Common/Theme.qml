pragma Singleton
import QtQuick

QtObject {
    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 12
    readonly property int spacingL: 16
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 18
    readonly property int cornerRadius: 12
    readonly property int iconSize: 24
    readonly property color primary: "#cc77ff"
    readonly property color onPrimary: { return "#111111"; }
    readonly property color surface: "#222222"
    readonly property color surfaceContainer: "#222222"
    readonly property color surfaceContainerHigh: "#333333"
    readonly property color surfaceContainerHighest: "#444444"
    readonly property color surfaceText: "#ffffff"
    readonly property color surfaceVariantText: "#cccccc"
    readonly property color outlineVariant: "#555555"
    readonly property color error: "#ff0000"
}
