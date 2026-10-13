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

    StyledText {
        width: parent.width
        text: I18n.trFor("dankTodo", "Dank Todo Settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("dankTodo", "A local, JSON-backed todo list for the Dank bar")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: storageColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: storageColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor("dankTodo", "Storage")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: 6

                StyledText {
                    text: I18n.trFor("dankTodo", "Storage directory")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                DankTextField {
                    id: pathInput
                    width: parent.width
                    placeholderText: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dank-todo"
                    text: root.loadValue("storagePath", "")
                    onEditingFinished: root.saveValue("storagePath", text.trim())
                }

                StyledText {
                    width: parent.width
                    text: I18n.trFor("dankTodo", "Todos are stored in todos.json inside this directory. Leave empty to use the default.")
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: displayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: displayColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor("dankTodo", "Display")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: 6

                StyledText {
                    text: I18n.trFor("dankTodo", "Bar pill count")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                Row {
                    id: modeRow
                    width: parent.width
                    spacing: Theme.spacingXS

                    property string currentMode: root.loadValue("countMode", "active")
                    property real chipWidth: (width - spacing * 4) / 5

                    Repeater {
                        model: [
                            {
                                key: "active",
                                label: I18n.trFor("dankTodo", "Active")
                            },
                            {
                                key: "paused",
                                label: I18n.trFor("dankTodo", "Paused")
                            },
                            {
                                key: "total",
                                label: I18n.trFor("dankTodo", "Total")
                            },
                            {
                                key: "done",
                                label: I18n.trFor("dankTodo", "Done")
                            },
                            {
                                key: "hidden",
                                label: I18n.trFor("dankTodo", "Hidden")
                            }
                        ]

                        Rectangle {
                            width: modeRow.chipWidth
                            height: 32
                            radius: Theme.cornerRadius
                            color: modeRow.currentMode === modelData.key ? Theme.primary : (chipArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                            border.width: modeRow.currentMode === modelData.key ? 0 : 1
                            border.color: Theme.outlineVariant

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: modeRow.currentMode === modelData.key ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    modeRow.currentMode = modelData.key
                                    root.saveValue("countMode", modelData.key)
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.trFor("dankTodo", "Which number to show next to the todo icon in the bar.")
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: limitsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: limitsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor("dankTodo", "Limits")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "maxItems"
                label: I18n.trFor("dankTodo", "Maximum todos")
                description: I18n.trFor("dankTodo", "Maximum number of stored todos")
                placeholder: "200"
                defaultValue: "200"
            }

            StringSetting {
                settingKey: "maxTextLength"
                label: I18n.trFor("dankTodo", "Maximum characters per todo")
                description: I18n.trFor("dankTodo", "Longer entries will be truncated when added")
                placeholder: "500"
                defaultValue: "500"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: ipcColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: ipcColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "terminal"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.trFor("dankTodo", "IPC commands")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                width: parent.width
                text: "dms ipc call dankTodo add \"Buy milk\"\ndms ipc call dankTodo toggle <id>\ndms ipc call dankTodo pause <id>\ndms ipc call dankTodo plan <id> \"2026-05-01\"\ndms ipc call dankTodo remove <id>\ndms ipc call dankTodo clearDone\ndms ipc call dankTodo list\ndms ipc call dankTodo count"
                font.pixelSize: Theme.fontSizeSmall
                font.family: "monospace"
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                lineHeight: 1.4
            }
        }
    }
}
