import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    popoutWidth: 500

    readonly property var service: PluginService.pluginDaemonInstances["dankTodo"] ?? null
    readonly property bool canWrite: !!service && service.connected && !service.busy && !draftAccountChanged
    readonly property var teams: service ? service.teams : []
    property string filter: "active"
    property var collapsedIds: []
    // Keep drafts outside the popout so closing it does not discard a failed write.
    property string draftTitle: ""
    property string draftDate: ""
    property string draftAccountId: ""
    readonly property bool draftAccountChanged: !!draftAccountId && !!service?.connected
        && !!service.viewer?.id && draftAccountId !== service.viewer.id
    onDraftTitleChanged: {
        if (draftTitle && !draftAccountId)
            draftAccountId = service?.viewer?.id || "";
    }
    onDraftDateChanged: {
        if (draftDate && !draftAccountId)
            draftAccountId = service?.viewer?.id || "";
    }
    property string editingId: ""
    property string parentId: ""
    property string teamId: ""
    property string stateId: ""
    property bool pendingSubmission: false
    property string composerError: ""
    readonly property string selectedTeamId: {
        if (teamId)
            return teamId;
        const preferred = String(pluginData.defaultTeamId || "");
        return teams.some(t => t.id === preferred) ? preferred : (teams[0]?.id || "");
    }
    readonly property var states: teams.find(t => t.id === selectedTeamId)?.states || []
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

    function resetDraft() {
        editingId = "";
        parentId = "";
        draftTitle = "";
        draftDate = "";
        stateId = "";
        teamId = "";
        composerError = "";
        draftAccountId = "";
    }

    function editIssue(issue) {
        if (!canWrite || issue.contextOnly || issue.isMine === false)
            return;
        resetDraft();
        draftAccountId = service.viewer.id;
        editingId = issue.id;
        draftTitle = issue.title;
        draftDate = issue.dueDate || "";
        teamId = issue.team.id;
        stateId = issue.state.id;
    }

    function addChild(issue) {
        if (!canWrite || issue.contextOnly || issue.isMine === false)
            return;
        resetDraft();
        draftAccountId = service.viewer.id;
        parentId = issue.id;
        teamId = issue.team.id;
        collapsedIds = collapsedIds.filter(id => id !== issue.id);
    }

    function submitDraft() {
        if (!canWrite || !draftTitle.trim() || !selectedTeamId || pendingSubmission)
            return;
        composerError = "";
        pendingSubmission = editingId
            ? service.updateIssue(editingId, draftTitle.trim(), stateId, draftDate.trim())
            : service.createIssue(draftTitle.trim(), selectedTeamId, parentId || null, draftDate.trim());
        if (!pendingSubmission && !service.error)
            composerError = I18n.trFor("dankTodo", "Could not start the request. Check the issue details and try again.");
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

    Connections {
        target: root.service
        function onMutationFinished(success) {
            if (!root.pendingSubmission)
                return;
            root.pendingSubmission = false;
            if (success)
                root.resetDraft();
        }
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

    component Choice: ComboBox {
        id: choice
        property string label: ""
        height: 42
        textRole: "name"
        Accessible.name: label
        opacity: enabled ? 1 : 0.5
        leftPadding: Theme.spacingM
        rightPadding: 32
        contentItem: StyledText {
            text: choice.displayText
            font.pixelSize: Theme.fontSizeMedium
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
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
            contentItem: StyledText { text: modelData.name; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            background: StyledRect {
                color: highlighted ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
            }
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
                color: Theme.surfaceContainerHigh
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Theme.outlineVariant
            }
        }
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
            headerText: I18n.trFor("dankTodo", "My Linear issues")
            detailsText: root.service?.connected
                ? I18n.trFor("dankTodo", "%1 active · %2 done").arg(root.service.activeCount).arg(root.service.doneCount)
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

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    StyledText {
                        width: parent.width - refreshButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.draftAccountChanged
                            ? I18n.trFor("dankTodo", "Account changed. Cancel this draft before continuing.")
                            : root.service?.error || root.composerError || (root.service?.busy
                            ? I18n.trFor("dankTodo", "Working…")
                            : root.service?.lastSyncedAt
                                ? I18n.trFor("dankTodo", "Updated %1").arg(Qt.formatDateTime(new Date(root.service.lastSyncedAt), "HH:mm"))
                                : I18n.trFor("dankTodo", "Not connected"))
                        color: root.draftAccountChanged || root.service?.error || root.composerError ? Theme.error : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }
                    DankButton {
                        id: refreshButton
                        objectName: "refreshIssues"
                        text: I18n.trFor("dankTodo", "Refresh")
                        iconName: "refresh"
                        enabled: !!root.service && !root.service.busy
                        onClicked: root.service.refresh()
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !!root.editingId || !!root.parentId
                    text: root.editingId ? I18n.trFor("dankTodo", "Editing %1").arg(root.service?.issues.find(t => t.id === root.editingId)?.identifier || "")
                        : I18n.trFor("dankTodo", "Sub-issue of %1").arg(root.service?.issues.find(t => t.id === root.parentId)?.identifier || "")
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeSmall
                }
                DankTextField {
                    id: titleInput
                    objectName: "issueTitle"
                    width: parent.width
                    enabled: root.canWrite
                    text: root.draftTitle
                    placeholderText: I18n.trFor("dankTodo", "Issue title")
                    onTextEdited: root.draftTitle = text
                    onAccepted: root.submitDraft()
                }
                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    Column {
                        width: (parent.width - parent.spacing) / 2
                        spacing: Theme.spacingXS
                        StyledText {
                            text: root.editingId ? I18n.trFor("dankTodo", "Status") : I18n.trFor("dankTodo", "Team")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        Choice {
                            objectName: "issueChoice"
                            width: parent.width
                            label: root.editingId ? I18n.trFor("dankTodo", "Status") : I18n.trFor("dankTodo", "Team")
                            enabled: root.canWrite && !root.parentId
                            model: root.editingId ? root.states : root.teams
                            currentIndex: model.findIndex(t => t.id === (root.editingId ? root.stateId : root.selectedTeamId))
                            onActivated: function(index) {
                                if (root.editingId)
                                    root.stateId = model[index].id;
                                else
                                    root.teamId = model[index].id;
                            }
                        }
                    }
                    Column {
                        width: (parent.width - parent.spacing) / 2
                        spacing: Theme.spacingXS
                        StyledText {
                            text: I18n.trFor("dankTodo", "Due date (optional)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        DankTextField {
                            objectName: "dueDate"
                            width: parent.width
                            enabled: root.canWrite
                            text: root.draftDate
                            placeholderText: I18n.trFor("dankTodo", "YYYY-MM-DD; empty clears")
                            onTextEdited: root.draftDate = text
                            onAccepted: root.submitDraft()
                        }
                    }
                }
                Row {
                    spacing: Theme.spacingS
                    DankButton {
                        objectName: "submitIssue"
                        text: root.editingId ? I18n.trFor("dankTodo", "Save changes") : I18n.trFor("dankTodo", "Create issue")
                        enabled: root.canWrite && !!root.draftTitle.trim() && !!root.selectedTeamId
                            && (!root.editingId || !!root.stateId)
                        onClicked: root.submitDraft()
                    }
                    DankButton {
                        objectName: "cancelDraft"
                        text: I18n.trFor("dankTodo", "Cancel")
                        visible: !!root.editingId || !!root.parentId || !!root.draftTitle || !!root.draftDate
                        enabled: !root.service?.busy
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        onClicked: root.resetDraft()
                    }
                }
                Row {
                    spacing: Theme.spacingS
                    Repeater {
                        model: [
                            { key: "active", name: I18n.trFor("dankTodo", "Active") },
                            { key: "all", name: I18n.trFor("dankTodo", "All") },
                            { key: "done", name: I18n.trFor("dankTodo", "Done") }
                        ]
                        DankButton {
                            text: modelData.name
                            buttonHeight: 32
                            backgroundColor: root.filter === modelData.key ? Theme.primary : Theme.surfaceContainerHigh
                            textColor: root.filter === modelData.key ? Theme.onPrimary : Theme.surfaceText
                            onClicked: root.filter = modelData.key
                        }
                    }
                }
                ListView {
                    objectName: "issueList"
                    width: parent.width
                    height: Math.min(contentHeight, 300)
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
                                iconName: root.collapsedIds.includes(issueRow.modelData.id) ? "chevron_right" : "expand_more"
                                opacity: issueRow.modelData.hasChildren ? 1 : 0
                                enabled: issueRow.modelData.hasChildren
                                label: root.collapsedIds.includes(issueRow.modelData.id)
                                    ? I18n.trFor("dankTodo", "Expand sub-issues") : I18n.trFor("dankTodo", "Collapse sub-issues")
                                onClicked: root.toggleExpanded(issueRow.modelData.id)
                            }
                            Column {
                                width: parent.width - 32 * 4 - parent.spacing * 4
                                spacing: Theme.spacingXS
                                StyledText {
                                    width: parent.width
                                    text: issueRow.modelData.title
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: issueRow.modelData.contextOnly ? Theme.surfaceVariantText : Theme.surfaceText
                                    wrapMode: Text.WordWrap
                                }
                                StyledText {
                                    width: parent.width
                                    text: issueRow.modelData.identifier + " · " + issueRow.modelData.state.name
                                        + (issueRow.modelData.dueDate ? " · " + I18n.trFor("dankTodo", "Due %1").arg(issueRow.modelData.dueDate) : "")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }
                            IconAction {
                                iconName: "edit"
                                objectName: "editIssue-" + issueRow.modelData.id
                                label: I18n.trFor("dankTodo", "Edit issue")
                                enabled: root.canWrite && !issueRow.modelData.contextOnly
                                onClicked: { root.editIssue(issueRow.modelData); titleInput.forceActiveFocus(); }
                            }
                            IconAction {
                                iconName: "subdirectory_arrow_right"
                                objectName: "addChild-" + issueRow.modelData.id
                                label: I18n.trFor("dankTodo", "Add sub-issue")
                                enabled: root.canWrite && !issueRow.modelData.contextOnly
                                onClicked: { root.addChild(issueRow.modelData); titleInput.forceActiveFocus(); }
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
                    text: I18n.trFor("dankTodo", "No issues in this view")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
