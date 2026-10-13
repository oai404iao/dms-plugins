import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankTodo"
    readonly property var service: PluginService.pluginDaemonInstances["dankTodo"] ?? null
    readonly property var teams: service ? service.teams : []
    property string keyPathError: ""

    function saveKeyPath() {
        const value = pathInput.text.trim();
        if (value && !value.startsWith("/")) {
            keyPathError = I18n.trFor("dankTodo", "Enter an absolute file path, not an API key.");
            return false;
        }
        keyPathError = "";
        root.saveValue("apiKeyPath", value);
        return true;
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("dankTodo", "Linear settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }
    StyledText {
        width: parent.width
        text: I18n.trFor("dankTodo", "Manage issues assigned to you in Linear.")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        StyledText {
            text: I18n.trFor("dankTodo", "API key file")
            font.pixelSize: Theme.fontSizeMedium
        }
        DankTextField {
            id: pathInput
            objectName: "apiKeyPath"
            width: parent.width
            enabled: !root.service?.busy
            placeholderText: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dank-todo/linear-api-key"
            text: root.loadValue("apiKeyPath", "")
            onEditingFinished: root.saveKeyPath()
        }
        StyledText {
            width: parent.width
            text: I18n.trFor("dankTodo", "Put your personal Linear API key in a local file containing only the key. Enter its absolute path here, not the key. Only the path is saved in settings. Leave empty to use the default path.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }
        DankButton {
            objectName: "reloadCredentials"
            text: I18n.trFor("dankTodo", "Reload key and test connection")
            iconName: "refresh"
            enabled: !!root.service && !root.service.busy
            onClicked: {
                if (!root.saveKeyPath())
                    return;
                Qt.callLater(() => root.service.reloadCredentials());
            }
        }
        StyledText {
            width: parent.width
            text: root.keyPathError || root.service?.error || (root.service?.busy ? I18n.trFor("dankTodo", "Working…")
                : root.service?.connected ? I18n.trFor("dankTodo", "Connected as %1").arg(root.service.viewer?.name || "")
                : I18n.trFor("dankTodo", "Not connected"))
            color: root.keyPathError || root.service?.error ? Theme.error : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    StyledText {
        text: I18n.trFor("dankTodo", "Default team")
        font.pixelSize: Theme.fontSizeMedium
    }
    ThemedChoice {
        objectName: "defaultTeamId"
        width: parent.width
        label: I18n.trFor("dankTodo", "Default team")
        enabled: root.teams.length > 0 && !root.service?.busy
        model: root.teams
        currentIndex: Math.max(0, root.teams.findIndex(t => t.id === root.loadValue("defaultTeamId", "")))
        onActivated: function(index) { root.saveValue("defaultTeamId", root.teams[index].id); }
    }

    StyledText {
        text: I18n.trFor("dankTodo", "Bar count")
        font.pixelSize: Theme.fontSizeMedium
    }
    ThemedChoice {
        objectName: "countMode"
        width: parent.width
        label: I18n.trFor("dankTodo", "Bar count")
        model: [
            { key: "active", name: I18n.trFor("dankTodo", "Active") },
            { key: "total", name: I18n.trFor("dankTodo", "Total") },
            { key: "done", name: I18n.trFor("dankTodo", "Done") },
            { key: "hidden", name: I18n.trFor("dankTodo", "Hidden") }
        ]
        currentIndex: Math.max(0, model.findIndex(t => t.key === root.loadValue("countMode", "active")))
        onActivated: function(index) { root.saveValue("countMode", model[index].key); }
    }

    component ThemedChoice: ComboBox {
        id: choice
        property string label: ""
        height: 42
        textRole: "name"
        Accessible.name: label
        opacity: enabled ? 1 : 0.5
        leftPadding: Theme.spacingM
        rightPadding: 32
        contentItem: StyledText { text: choice.displayText; wrapMode: Text.NoWrap; elide: Text.ElideRight }
        indicator: DankIcon {
            x: choice.width - width - Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 18
            color: Theme.surfaceVariantText
        }
        background: StyledRect {
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            border.width: choice.activeFocus ? 2 : 1
            border.color: choice.activeFocus ? Theme.primary : Theme.outlineVariant
        }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: choice.width
            highlighted: choice.highlightedIndex === index
            contentItem: StyledText { text: modelData.name; wrapMode: Text.NoWrap; elide: Text.ElideRight }
            background: StyledRect { color: highlighted ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh }
        }
        popup: Popup {
            width: choice.width
            y: choice.height + Theme.spacingXS
            padding: Theme.spacingXS
            implicitHeight: Math.min(contentItem.implicitHeight + padding * 2, 220)
            contentItem: ListView {
                implicitHeight: contentHeight
                clip: true
                model: choice.popup.visible ? choice.delegateModel : null
                currentIndex: choice.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator {}
            }
            background: StyledRect {
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.outlineVariant
            }
        }
    }
}
