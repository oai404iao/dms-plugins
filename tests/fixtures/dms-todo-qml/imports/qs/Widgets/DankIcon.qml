import QtQuick

// Glyph stand-ins make mocked screenshots legible without host icon fonts.
Text {
    property string name: ""
    property real size: 24
    text: ({
        refresh: "↻", check_circle: "✓", radio_button_unchecked: "○",
        cancel: "⊘", account_tree: "⋈", chevron_right: "›",
        expand_more: "⌄", open_in_new: "↗", checklist: "☑", link_off: "×"
    })[name] || "·"
    color: "white"
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    width: size
    height: size
}
