import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    popoutWidth: 460

    readonly property var service: PluginService.pluginDaemonInstances["dankTodo"] ?? null
    property string filter: "active"
    property var collapsedIds: []
    readonly property var rows: {
        if (!service)
            return [];
        service.issues;
        return service.treeRows(filter, collapsedIds);
    }
    readonly property string countLabel: {
        if (!service?.connected || pluginData.countMode === "hidden")
            return "";
        const mode = pluginData.countMode || "active";
        return String(mode === "done" ? service.doneCount
            : mode === "total" ? service.activeCount + service.doneCount : service.activeCount);
    }

    function isClosed(issue) {
        return ["completed", "canceled", "duplicate"].includes(issue.state.type);
    }

    function hasCompletedState(issue) {
        return !!service?.teams.find(t => t.id === issue.team.id)?.states.some(s => s.type === "completed");
    }

    function toggleExpanded(id) {
        collapsedIds = collapsedIds.includes(id)
            ? collapsedIds.filter(value => value !== id) : collapsedIds.concat([id]);
    }

    function displayTime(value) {
        const date = value ? new Date(value) : null;
        return date && !isNaN(date.getTime()) ? Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
            : I18n.trFor("dankTodo", "Not set");
    }

    component IconAction: DankButton {
        property string label: ""
        property string tooltipText: label
        width: 32
        buttonHeight: 32
        horizontalPadding: 0
        iconSize: 18
        backgroundColor: "transparent"
        textColor: Theme.surfaceVariantText
        Accessible.name: label
        ToolTip.visible: hovered || activeFocus
        ToolTip.text: tooltipText
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon {
                name: root.service?.connected ? "checklist" : "link_off"
                size: Theme.iconSize - 6
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.countLabel
                visible: text.length > 0
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: root.service?.connected ? "checklist" : "link_off"
                size: Theme.iconSize - 6
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.countLabel
                visible: text.length > 0
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: I18n.trFor("dankTodo", "My tasks")
            detailsText: root.service?.connected
                ? I18n.trFor("dankTodo", "%1 remaining").arg(root.service.activeCount)
                : I18n.trFor("dankTodo", "Configure your API key file in settings")
            showCloseButton: true
            onVisibleChanged: {
                if (visible && root.service)
                    root.service.refresh();
            }
            Component.onCompleted: {
                if (visible && root.service)
                    root.service.refresh();
            }

            Column {
                width: popout.width
                spacing: Theme.spacingM

                Item {
                    width: parent.width
                    height: 32
                    Row {
                        anchors.left: parent.left
                        spacing: Theme.spacingS
                        Repeater {
                            model: [
                                { key: "active", name: I18n.trFor("dankTodo", "Pending"), count: root.service?.activeCount || 0 },
                                { key: "done", name: I18n.trFor("dankTodo", "Closed"), count: root.service?.doneCount || 0 }
                            ]
                            DankButton {
                                objectName: "filter-" + modelData.key
                                text: modelData.name + (root.service?.connected ? " · " + modelData.count : "")
                                buttonHeight: 32
                                backgroundColor: root.filter === modelData.key ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: root.filter === modelData.key ? Theme.onPrimary : Theme.surfaceText
                                onClicked: root.filter = modelData.key
                            }
                        }
                    }
                    IconAction {
                        anchors.right: parent.right
                        objectName: "refreshIssues"
                        iconName: "refresh"
                        label: I18n.trFor("dankTodo", "Refresh")
                        enabled: !!root.service && !root.service.busy
                        onClicked: root.service.refresh()
                    }
                }
                StyledText {
                    width: parent.width
                    text: root.service?.error || (root.service?.busy
                        ? root.service.pendingIssueId ? I18n.trFor("dankTodo", "Completing task…")
                            : I18n.trFor("dankTodo", "Refreshing…")
                        : root.service?.lastSyncedAt
                            ? I18n.trFor("dankTodo", "Updated %1").arg(Qt.formatDateTime(new Date(root.service.lastSyncedAt), "HH:mm"))
                            : I18n.trFor("dankTodo", "Not connected"))
                    color: root.service?.error ? Theme.error : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
                ListView {
                    objectName: "issueList"
                    width: parent.width
                    height: Math.min(contentHeight, 360)
                    clip: true
                    spacing: Theme.spacingXS
                    model: root.rows
                    ScrollIndicator.vertical: ScrollIndicator {}
                    delegate: StyledRect {
                        id: issueRow
                        required property var modelData
                        width: ListView.view.width
                        height: rowContent.implicitHeight + Theme.spacingS * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        Row {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingS
                            anchors.leftMargin: Theme.spacingS + Math.min(issueRow.modelData.depth, 3) * Theme.spacingM
                            spacing: Theme.spacingXS
                            IconAction {
                                iconName: issueRow.modelData.contextOnly ? "account_tree"
                                    : issueRow.modelData.state.type === "completed" ? "check_circle"
                                    : root.isClosed(issueRow.modelData) ? "cancel" : "radio_button_unchecked"
                                objectName: "completeIssue-" + issueRow.modelData.id
                                label: issueRow.modelData.contextOnly ? I18n.trFor("dankTodo", "Parent issue (context)")
                                    : root.isClosed(issueRow.modelData) ? I18n.trFor("dankTodo", "Closed")
                                    : I18n.trFor("dankTodo", "Complete task")
                                enabled: !issueRow.modelData.contextOnly && !!root.service?.canCompleteIssue(issueRow.modelData.id)
                                textColor: Theme.surfaceVariantText
                                onClicked: root.service.completeIssue(issueRow.modelData.id)
                            }
                            IconAction {
                                width: 20
                                objectName: "expandIssue-" + issueRow.modelData.id
                                iconName: root.collapsedIds.includes(issueRow.modelData.id) ? "chevron_right" : "expand_more"
                                opacity: issueRow.modelData.hasChildren ? 1 : 0
                                enabled: issueRow.modelData.hasChildren
                                label: root.collapsedIds.includes(issueRow.modelData.id)
                                    ? I18n.trFor("dankTodo", "Expand sub-issues") : I18n.trFor("dankTodo", "Collapse sub-issues")
                                onClicked: root.toggleExpanded(issueRow.modelData.id)
                            }
                            Column {
                                width: parent.width - 32 * 2 - 20 - parent.spacing * 3
                                spacing: Theme.spacingXS
                                StyledText {
                                    width: parent.width
                                    text: issueRow.modelData.title
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.strikeout: issueRow.modelData.state.type === "completed" && !issueRow.modelData.contextOnly
                                    color: issueRow.modelData.contextOnly ? Theme.surfaceVariantText : Theme.surfaceText
                                    wrapMode: Text.WordWrap
                                }
                                StyledText {
                                    width: parent.width
                                    text: issueRow.modelData.identifier + " · " + issueRow.modelData.state.name
                                        + (issueRow.modelData.team.name ? " · " + issueRow.modelData.team.name : "")
                                        + (issueRow.modelData.dueDate ? " · " + I18n.trFor("dankTodo", "Due %1").arg(issueRow.modelData.dueDate) : "")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                                StyledText {
                                    width: parent.width
                                    visible: !issueRow.modelData.contextOnly && !root.isClosed(issueRow.modelData)
                                        && !root.hasCompletedState(issueRow.modelData)
                                    text: I18n.trFor("dankTodo", "No completed status")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }
                            IconAction {
                                iconName: "open_in_new"
                                objectName: "openIssue-" + issueRow.modelData.id
                                label: I18n.trFor("dankTodo", "Open in Linear")
                                tooltipText: label + "\n"
                                    + I18n.trFor("dankTodo", "Created: %1").arg(root.displayTime(issueRow.modelData.createdAt)) + "\n"
                                    + I18n.trFor("dankTodo", "Completed: %1").arg(root.displayTime(issueRow.modelData.completedAt))
                                enabled: /^https:\/\/linear\.app\//.test(String(issueRow.modelData.url || ""))
                                onClicked: Qt.openUrlExternally(issueRow.modelData.url)
                            }
                        }
                    }
                }
                StyledText {
                    width: parent.width
                    visible: root.rows.length === 0 && !!root.service?.connected && !root.service.busy
                    text: root.filter === "active" ? I18n.trFor("dankTodo", "No pending tasks")
                        : I18n.trFor("dankTodo", "No closed tasks")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
