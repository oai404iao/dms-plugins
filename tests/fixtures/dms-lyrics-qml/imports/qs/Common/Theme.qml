pragma Singleton
import QtQuick

QtObject {
    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 12
    readonly property int spacingL: 16
    readonly property int spacingXL: 24
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 18
    readonly property int cornerRadius: 12
    readonly property real popupTransparency: 1.0
    readonly property color primary: "#ff00ff"
    readonly property color primaryHover: "#ff44ff"
    readonly property color surfaceText: "#ffffff"
    readonly property color surfaceVariantText: "#cccccc"
    readonly property color surfaceVariant: "#333333"
    readonly property color floatingSurface: "#222222"
    readonly property color nestedSurface: "#2a2a2a"
    readonly property color outline: "#555555"
    readonly property color outlineStrong: "#777777"
    readonly property color outlineHeavy: "#666666"
    readonly property bool connectedSurfaceBlurEnabled: true
    readonly property bool isDirectionalEffect: true
    readonly property real effectScaleCollapsed: 0.85
    readonly property real variantOpacityDurationScale: 1.0
    readonly property var variantPopoutEnterCurve: [0.2, 0, 0, 1]
    readonly property var variantPopoutExitCurve: [0.4, 0, 1, 1]
    readonly property bool elevationEnabled: true
    readonly property var elevationLevel2: ({ alpha: 0.25 })
    readonly property var expressiveDurations: ({ expressiveDefaultSpatial: 100 })

    function variantDuration(baseDuration, entering) {
        return 0;
    }

    function withAlpha(c, a) {
        return c;
    }
}
