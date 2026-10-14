import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "plugin"
import "plugin/LinearApi.js" as Api

TestCase {
    id: suite
    name: "DankTodoLinearIntegration"
    width: 700
    height: 1000
    visible: true
    when: windowShown

    Component { id: daemonComponent; LinearService { pluginId: "dankTodo"; pluginService: PluginService } }
    Component { id: widgetComponent; DankTodoWidget {} }
    Component { id: settingsComponent; DankTodoSettings {} }
    property var daemon: null
    property var widget: null
    property var secondWidget: null
    property var popout: null
    property var settings: null
    property var mutationResults: []
    Connections {
        target: suite.daemon
        function onMutationFinished(success) { suite.mutationResults = suite.mutationResults.concat([success]); }
    }

    function init() {
        verify(Quickshell.isStub, "never load real Quickshell IO");
        Api.reset();
        I18n.localeTag = "en_US";
        I18n.pluginTranslations = ({});
        SettingsData.pluginSettings = ({dankTodo: {}});
        Quickshell.commands = [];
        mutationResults = [];
        daemon = daemonComponent.createObject(suite);
        verify(daemon !== null);
        PluginService.pluginDaemonInstances = ({dankTodo: daemon});
        compare(TestIo.file.reloadCount, 1);
        compare(TestIo.file.writeCount, 0);
        compare(TestIo.file.path, "/fixture/config/dank-todo/linear-api-key");
        verify(TestIo.file.watchChanges);
    }

    function cleanup() {
        if (settings) settings.destroy();
        if (popout) popout.destroy();
        if (secondWidget) secondWidget.destroy();
        if (widget) widget.destroy();
        if (daemon) daemon.destroy();
        settings = null; popout = null; secondWidget = null; widget = null; daemon = null;
        PluginService.pluginDaemonInstances = ({});
        wait(0);
        TestIo.file = null;
        TestIo.ipc = null;
        Api.reset();
    }

    function state(id, type, position) {
        return {id: id, name: id, color: "#aabbcc", type: type, position: position || 0};
    }
    function team(id, completedId) {
        return {id: id || "team", name: "Test team", states: {
            nodes: [state(completedId || "done", "completed", 2), state("active", "started", 1), state("cancel", "canceled", 3)],
            pageInfo: {hasNextPage: false}
        }};
    }
    function issue(id, type, parent) {
        return {id: id, identifier: "TEST-" + id, title: "Issue " + id,
            url: "https://linear.app/test/issue/" + id,
            createdAt: "2026-01-02T03:04:05Z", completedAt: null, dueDate: null,
            state: state(type === "completed" ? "done" : type === "canceled" ? "cancel" : "active", type || "started"),
            team: {id: "team", name: "Test team"}, parent: parent || null};
    }
    function page(nodes, cursor) {
        return {nodes: nodes, pageInfo: {hasNextPage: !!cursor, endCursor: cursor || null}};
    }
    function ids(rows) { return rows.map(t => t.id).join(","); }
    function request() { verify(Api.pending.length > 0); return Api.pending[0]; }
    function complete(data, error) { Api.complete(data, error); wait(0); }
    function bootstrap(tasks, teams) {
        TestIo.file.inject("fixture-key\n");
        compare(request().query, Api.bootstrapQuery);
        complete({viewer: {id: "viewer", name: "Viewer"}, teams: page(teams || [team()])});
        compare(request().query, Api.issuesQuery);
        complete({issues: page(tasks || [issue("mine")])});
        compare(daemon.busy, false);
        verify(daemon.connected);
    }
    function descendants(item, predicate) {
        let found = [];
        if (predicate(item)) found.push(item);
        for (const child of item.children || [])
            found = found.concat(descendants(child, predicate));
        return found;
    }
    function makeUi() {
        widget = widgetComponent.createObject(suite);
        secondWidget = widgetComponent.createObject(suite);
        verify(widget !== null && secondWidget !== null);
        popout = widget.popoutContent.createObject(suite);
        verify(popout !== null);
        wait(0);
        if (Api.pending.length) {
            compare(request().query, Api.bootstrapQuery);
            const tasks = daemon.issues.filter(t => t.isMine);
            complete({viewer: {id: daemon.viewer.id, name: "Viewer"}, teams: page(daemon.teams.map(t => ({
                id: t.id, name: t.name, states: page(t.states)
            })))});
            complete({issues: page(tasks)});
        }
    }
    function named(item, name) {
        const matches = descendants(item, child => child.objectName === name);
        compare(matches.length, 1, name);
        return matches[0];
    }

    function test_paginated_teams_my_issues_and_context_ancestors() {
        TestIo.file.inject("fixture-key");
        compare(request().variables.after, null);
        complete({viewer: {id: "viewer"}, teams: page([team()], "team-cursor")});
        compare(request().variables.after, "team-cursor");
        complete({viewer: {id: "viewer"}, teams: page([team("team2")])});
        compare(daemon.teams.length, 2);
        compare(daemon.teams[0].states.map(s => s.id).join(","), "active,done,cancel");
        compare(request().variables.viewer, "viewer");
        const middle = issue("middle", "canceled", {id: "root"});
        complete({issues: page([issue("leaf", "started", middle)], "issue-cursor")});
        compare(request().variables.after, "issue-cursor");
        compare(request().variables.viewer, "viewer");
        complete({issues: page([issue("done", "completed"), issue("cancel", "canceled")])});
        compare(request().query, Api.parentQuery);
        compare(request().variables.id, "root");
        complete({issue: issue("root", "completed")});
        compare(daemon.activeCount, 1);
        compare(daemon.doneCount, 2);
        const rows = daemon.treeRows("active", []);
        compare(ids(rows), "root,middle,leaf");
        compare(rows.map(t => t.depth).join(","), "0,1,2");
        compare(rows.map(t => t.contextOnly).join(","), "true,true,false");
        compare(ids(daemon.treeRows("active", ["middle"])), "root,middle");
        compare(ids(daemon.treeRows("done", [])), "done,cancel");
        verify(daemon.lastSyncedAt.length > 0);
        compare(TestIo.file.writeCount, 0);
    }

    function test_completion_updates_only_state_and_waits_for_refreshed_snapshot() {
        const mine = issue("mine");
        mine.dueDate = "2028-02-29";
        bootstrap([mine, issue("other")]);
        const snapshot = JSON.stringify(daemon.issues);
        verify(daemon.canCompleteIssue("mine"));
        verify(daemon.completeIssue("mine"));
        compare(daemon.pendingIssueId, "mine");
        compare(request().query, Api.updateMutation);
        compare(JSON.stringify(request().variables), JSON.stringify({id: "mine", input: {stateId: "done"}}));
        compare(JSON.stringify(daemon.issues), snapshot, "never complete optimistically");
        compare(daemon.activeCount, 2);
        const calls = Api.history.length;
        compare(daemon.canCompleteIssue("other"), false);
        compare(daemon.completeIssue("mine"), false);
        compare(daemon.completeIssue("other"), false);
        compare(daemon.refresh(), false);
        compare(Api.history.length, calls, "only one task write may be in flight");
        complete({issueUpdate: {success: true}});
        compare(mutationResults.join(","), "true");
        compare(daemon.pendingIssueId, "");
        verify(daemon.busy, "confirmed completion still waits for refresh");
        compare(request().query, Api.issuesQuery);
        compare(request().variables.viewer, "viewer");
        compare(JSON.stringify(daemon.issues), snapshot);
        const done = issue("mine", "completed");
        done.dueDate = mine.dueDate;
        complete({issues: page([done, issue("other")])});
        compare(ids(daemon.treeRows("active", [])), "other");
        compare(ids(daemon.treeRows("done", [])), "mine");
        compare(daemon.doneCount, 1);
        compare(daemon.activeCount, 1);
        compare(daemon.issues[0].title, mine.title);
        compare(daemon.issues[0].dueDate, mine.dueDate);
        compare(TestIo.file.writeCount, 0);
    }

    function test_completion_uses_each_issues_team_completed_state() {
        const second = issue("second");
        second.team = {id: "team2", name: "Second team"};
        bootstrap([issue("mine"), second], [team(), team("team2", "team2-done")]);
        verify(daemon.completeIssue("second"));
        compare(JSON.stringify(request().variables), JSON.stringify({id: "second", input: {stateId: "team2-done"}}));
        complete({issueUpdate: {success: true}});
        const done = issue("second", "completed");
        done.team = second.team;
        complete({issues: page([issue("mine"), done])});
        verify(daemon.completeIssue("mine"));
        compare(JSON.stringify(request().variables), JSON.stringify({id: "mine", input: {stateId: "done"}}));
        complete({issueUpdate: {success: true}});
        complete({issues: page([issue("mine", "completed"), done])});
        compare(daemon.activeCount, 0);
        compare(daemon.doneCount, 2);
    }

    function test_completion_invalid_closed_and_context_are_read_only() {
        bootstrap([issue("mine", "started", issue("context")), issue("done", "completed"),
                   issue("cancel", "canceled"), issue("duplicate", "duplicate")]);
        const calls = Api.history.length;
        for (const id of ["", "missing", "context", "done", "cancel", "duplicate"]) {
            compare(daemon.canCompleteIssue(id), false, id);
            compare(daemon.completeIssue(id), false, id);
        }
        compare(typeof daemon.createIssue, "undefined");
        compare(typeof daemon.updateIssue, "undefined");
        compare(Api.history.length, calls);
    }

    function test_completion_requires_team_completed_state_connected_and_idle() {
        const noStatus = team();
        noStatus.states = page([state("active", "started"), state("cancel", "canceled")]);
        bootstrap([issue("mine")], [noStatus]);
        const calls = Api.history.length;
        compare(daemon.canCompleteIssue("mine"), false);
        compare(daemon.completeIssue("mine"), false);
        daemon.teams = [];
        compare(daemon.canCompleteIssue("mine"), false, "unknown team is not completable");
        daemon.teams = [{id: "team", states: team().states.nodes}];
        verify(daemon.canCompleteIssue("mine"));
        daemon.connected = false;
        compare(daemon.canCompleteIssue("mine"), false);
        compare(daemon.completeIssue("mine"), false);
        daemon.connected = true;
        daemon.busy = true;
        compare(daemon.canCompleteIssue("mine"), false);
        compare(daemon.completeIssue("mine"), false);
        daemon.busy = false;
        daemon.viewer = null;
        compare(daemon.canCompleteIssue("mine"), false);
        compare(daemon.completeIssue("mine"), false);
        compare(Api.history.length, calls);
    }

    function test_mutation_failure_signal_and_failed_refresh_retains_snapshot() {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        const syncedAt = daemon.lastSyncedAt;
        verify(daemon.completeIssue("mine"));
        complete({issueUpdate: {success: false}});
        compare(mutationResults.join(","), "false");
        compare(JSON.stringify(daemon.issues), snapshot);
        compare(daemon.pendingIssueId, "");
        verify(daemon.error.length > 0);
        verify(daemon.refresh());
        complete({viewer: {id: "viewer"}, teams: page([team()])});
        complete(null, "network");
        compare(daemon.busy, false);
        compare(JSON.stringify(daemon.issues), snapshot);
        compare(daemon.lastSyncedAt, syncedAt);
        verify(daemon.error.length > 0);
    }

    function test_confirmed_completion_failed_refresh_retains_snapshot() {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        const syncedAt = daemon.lastSyncedAt;
        verify(daemon.completeIssue("mine"));
        complete({issueUpdate: {success: true}});
        compare(mutationResults.join(","), "true");
        complete(null, "network");
        compare(daemon.busy, false);
        compare(daemon.pendingIssueId, "");
        compare(JSON.stringify(daemon.issues), snapshot);
        compare(daemon.lastSyncedAt, syncedAt);
        verify(daemon.error.length > 0);
        verify(daemon.refresh());
        complete({viewer: {id: "viewer"}, teams: page([team()])});
        complete({issues: page([issue("mine", "completed")])});
        compare(daemon.activeCount, 0, "refresh reconciles confirmed completion");
    }

    function test_completion_transport_errors_data() {
        return ["auth", "rate", "response", "network"].map(code => ({tag: code, code: code}));
    }
    function test_completion_transport_errors(data) {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        verify(daemon.completeIssue("mine"));
        complete(null, data.code);
        compare(mutationResults.join(","), "false");
        compare(JSON.stringify(daemon.issues), snapshot);
        compare(daemon.busy, false);
        compare(daemon.pendingIssueId, "");
        verify(daemon.error.length > 0);
        compare(daemon.connected, data.code !== "auth");
    }

    function test_malformed_pages_data() {
        return [
            {tag: "missing viewer", data: {teams: page([team()])}},
            {tag: "missing team nodes", data: {viewer: {id: "viewer"}, teams: {pageInfo: {hasNextPage: false}}}},
            {tag: "missing cursor", data: {viewer: {id: "viewer"}, teams: {nodes: [], pageInfo: {hasNextPage: true}}}},
            {tag: "unavailable states", data: {viewer: {id: "viewer"}, teams: page([{id: "team", states: null}])}}
        ];
    }
    function test_malformed_pages(data) {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        verify(daemon.refresh());
        complete(data.data);
        compare(daemon.busy, false);
        verify(daemon.error.length > 0);
        compare(JSON.stringify(daemon.issues), snapshot);
    }

    function test_malformed_issue_page_retains_snapshot() {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        for (const data of [{issues: {nodes: null}}, {issues: page([{id: "bad", title: "Missing state"}])}]) {
            verify(daemon.refresh());
            complete({viewer: {id: "viewer"}, teams: page([team()])});
            complete(data);
            compare(daemon.busy, false);
            verify(daemon.error.length > 0);
            compare(JSON.stringify(daemon.issues), snapshot);
        }
    }

    function test_errors_data() {
        return ["auth", "rate", "response", "network"].map(code => ({tag: code, code: code}));
    }
    function test_errors(data) {
        bootstrap();
        verify(daemon.refresh());
        complete(null, data.code);
        compare(daemon.busy, false);
        verify(daemon.error.length > 0);
        compare(daemon.connected, data.code !== "auth");
        compare(daemon.issues.length, 1);
    }

    function test_timeout_aborts_and_ignores_late_response() {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        verify(daemon.completeIssue("mine"));
        const outstanding = request();
        const timers = daemon.resources.filter(o => o.interval === 20000 && o.triggered !== undefined);
        compare(timers.length, 1);
        timers[0].triggered();
        verify(outstanding.canceled);
        compare(daemon.busy, false);
        compare(daemon.pendingIssueId, "");
        compare(mutationResults.join(","), "false");
        verify(daemon.error.indexOf("timed out") >= 0);
        complete({issueUpdate: {success: true}});
        compare(mutationResults.join(","), "false");
        compare(JSON.stringify(daemon.issues), snapshot);
    }

    function test_credential_changes_cancel_requests_and_reset_account() {
        bootstrap();
        verify(daemon.refresh());
        const old = request();
        SettingsData.pluginSettings = ({dankTodo: {apiKeyPath: " /fixture/new-key "}});
        compare(TestIo.file.path, "/fixture/new-key");
        verify(old.canceled);
        compare(daemon.viewer, null);
        compare(daemon.teams.length, 0);
        compare(daemon.issues.length, 0);
        compare(daemon.lastSyncedAt, "");
        compare(daemon.connected, false);
        complete({viewer: {id: "old"}, teams: page([team()])});
        compare(daemon.viewer, null, "old callback must not populate a new account");
        TestIo.file.inject("new-fixture-key");
        compare(request().key, "new-fixture-key");
        complete({viewer: {id: "new"}, teams: page([team()])});
        complete({issues: page([])});
        compare(daemon.viewer.id, "new");
        verify(daemon.refresh());
        const watched = request();
        TestIo.file.fileChanged();
        verify(watched.canceled);
        compare(daemon.viewer, null);
        compare(daemon.issues.length, 0);
        compare(TestIo.file.writeCount, 0);
    }

    function test_credential_rotation_during_completion_ignores_stale_success() {
        bootstrap();
        verify(daemon.completeIssue("mine"));
        const old = request();
        TestIo.file.fileChanged();
        verify(old.canceled);
        compare(daemon.pendingIssueId, "");
        compare(daemon.busy, false);
        compare(daemon.viewer, null);
        compare(daemon.issues.length, 0);
        compare(mutationResults.join(","), "false");
        complete({issueUpdate: {success: true}});
        compare(Api.pending.length, 0, "stale success must not refresh another account");
        compare(mutationResults.join(","), "false");
        TestIo.file.inject("rotated-fixture-key");
        compare(request().key, "rotated-fixture-key");
        complete({viewer: {id: "other-viewer"}, teams: page([team()])});
        complete({issues: page([issue("other")])});
        compare(daemon.viewer.id, "other-viewer");
        compare(daemon.canCompleteIssue("mine"), false);
        compare(daemon.completeIssue("mine"), false);
        verify(daemon.completeIssue("other"));
        compare(request().key, "rotated-fixture-key");
        compare(request().variables.id, "other");
        complete({issueUpdate: {success: true}});
        complete({issues: page([issue("other", "completed")])});
        compare(TestIo.file.writeCount, 0);
    }

    function test_malformed_and_unreadable_credentials_never_write() {
        for (const contents of ["", " \n ", "two keys", "key\nother"]) {
            TestIo.file.inject(contents);
            compare(Api.history.length, 0);
            compare(daemon.connected, false);
            verify(daemon.error.length > 0);
        }
        TestIo.file.loadFailed(2);
        verify(daemon.error.indexOf("Cannot read") >= 0);
        compare(TestIo.file.writeCount, 0);
        compare(Quickshell.commands.length, 0, "no mkdir, migration or credential writes");
    }

    function test_ipc_is_read_only_and_never_exposes_credentials() {
        bootstrap([issue("mine"), issue("done", "completed"), issue("child", "started", issue("context"))]);
        const json = TestIo.ipc.list();
        compare(ids(JSON.parse(json)), "mine,done,child");
        verify(!json.includes("fixture-key"));
        compare(TestIo.ipc.count(), "2/3");
        compare(TestIo.ipc.target, "dankTodo");
        for (const name of ["add", "edit", "delete", "plan", "pause", "complete", "completeIssue", "setKey", "setToken"])
            compare(typeof TestIo.ipc[name], "undefined", name);
        compare(TestIo.ipc.refresh(), "STARTED");
        compare(TestIo.ipc.refresh(), "NOT_STARTED");
        compare(TestIo.file.writeCount, 0);
    }

    function test_ui_two_widgets_share_daemon_and_context_controls() {
        bootstrap([issue("child", "started", issue("context", "completed"))]);
        makeUi();
        compare(widget.service, daemon);
        compare(secondWidget.service, daemon);
        compare(TestIo.file.reloadCount, 1, "widgets never own credential IO");
        const list = named(popout, "issueList");
        tryCompare(list, "count", 2);
        wait(50);
        verify(list.itemAtIndex(0) !== null && list.itemAtIndex(1) !== null);
        const context = list.itemAtIndex(0);
        compare(context.modelData.contextOnly, true);
        compare(named(context, "completeIssue-context").enabled, false);
        compare(named(context, "openIssue-context").enabled, true);
        const child = list.itemAtIndex(1);
        compare(named(child, "completeIssue-child").enabled, true);
        const removed = descendants(popout, child => /^(editIssue-|addChild-)/.test(child.objectName)
            || ["issueTitle", "dueDate", "issueChoice", "submitIssue", "cancelDraft"].includes(child.objectName));
        compare(removed.length, 0, "no creation or editing controls remain");
        named(context, "expandIssue-context").clicked();
        tryCompare(list, "count", 1);
        named(list.itemAtIndex(0), "expandIssue-context").clicked();
        tryCompare(list, "count", 2);
        compare(widget.filter, "active");
        for (const filter of ["done", "active"]) {
            named(popout, "filter-" + filter).clicked();
            compare(widget.filter, filter);
            tryCompare(list, "count", daemon.treeRows(filter, []).length);
        }
        for (const mode of ["active", "total", "done", "hidden"]) {
            widget.pluginData = ({countMode: mode});
            compare(widget.countLabel, mode === "hidden" ? "" : mode === "done" ? "0" : "1");
        }
        const horizontal = widget.horizontalBarPill.createObject(suite);
        const vertical = widget.verticalBarPill.createObject(suite);
        verify(horizontal !== null && vertical !== null);
        horizontal.destroy();
        vertical.destroy();
        compare(TestIo.file.writeCount, 0);
    }

    function test_ui_completion_shared_state_failure_and_closed_view() {
        bootstrap([issue("mine"), issue("other")]);
        makeUi();
        compare(popout.headerText, "My tasks");
        compare(popout.detailsText, "2 remaining");
        const list = named(popout, "issueList");
        tryCompare(list, "count", 2);
        wait(50);
        named(list.itemAtIndex(0), "completeIssue-mine").clicked();
        compare(daemon.pendingIssueId, "mine");
        compare(request().variables.id, "mine");
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, false);
        compare(named(list.itemAtIndex(1), "completeIssue-other").enabled, false);
        compare(named(popout, "refreshIssues").enabled, false);
        compare(secondWidget.service.pendingIssueId, "mine");
        compare(ids(secondWidget.rows), "mine,other", "both widgets retain unconfirmed snapshot");
        verify(descendants(popout, child => child.text === "Completing task…").length > 0);
        complete(null, "network");
        compare(ids(widget.rows), "mine,other");
        compare(ids(secondWidget.rows), "mine,other");
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, true);
        named(list.itemAtIndex(0), "completeIssue-mine").clicked();
        complete({issueUpdate: {success: true}});
        compare(ids(widget.rows), "mine,other", "confirmed write waits for fresh list");
        complete({issues: page([issue("mine", "completed"), issue("other")])});
        tryCompare(list, "count", 1);
        compare(ids(widget.rows), "other");
        compare(ids(secondWidget.rows), "other");
        compare(popout.detailsText, "1 remaining");
        named(popout, "filter-done").clicked();
        tryCompare(list, "count", 1);
        wait(50);
        compare(list.itemAtIndex(0).modelData.id, "mine");
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, false);
        compare(named(list.itemAtIndex(0), "openIssue-mine").enabled, true);
        compare(secondWidget.filter, "active", "filters remain widget-local");
        compare(TestIo.file.writeCount, 0);
    }

    function test_ui_missing_completed_status_busy_and_offline() {
        const noStatus = team();
        noStatus.states = page([state("active", "started")]);
        bootstrap([issue("mine")], [noStatus]);
        makeUi();
        const list = named(popout, "issueList");
        tryCompare(list, "count", 1);
        wait(50);
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, false);
        compare(descendants(popout, child => child.visible && child.text === "No completed status").length, 1);
        daemon.teams = [{id: "team", states: team().states.nodes}];
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, true);
        compare(descendants(popout, child => child.visible && child.text === "No completed status").length, 0);
        named(popout, "refreshIssues").clicked();
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, false);
        verify(descendants(popout, child => child.text === "Refreshing…").length > 0);
        complete(null, "auth");
        compare(named(list.itemAtIndex(0), "completeIssue-mine").enabled, false);
        compare(named(list.itemAtIndex(0), "openIssue-mine").enabled, true);
        compare(list.count, 1, "offline snapshot remains readable");
    }

    function test_ui_synchronous_transport_failure_retains_snapshot() {
        bootstrap();
        makeUi();
        const snapshot = JSON.stringify(daemon.issues);
        Api.nextError = "network";
        verify(daemon.completeIssue("mine"));
        verify(daemon.busy, "failure callback must not race caller state");
        compare(daemon.pendingIssueId, "mine");
        wait(0);
        compare(daemon.pendingIssueId, "");
        compare(JSON.stringify(daemon.issues), snapshot);
        compare(mutationResults.join(","), "false");
        compare(daemon.busy, false);
    }

    function test_ui_keyboard_focus_accessible_actions() {
        bootstrap([issue("child", "started", issue("context"))]);
        makeUi();
        const list = named(popout, "issueList");
        tryCompare(list, "count", 2);
        wait(50);
        const refresh = named(popout, "refreshIssues");
        const pending = named(popout, "filter-active");
        pending.forceActiveFocus();
        tryCompare(pending, "activeFocus", true);
        keyClick(Qt.Key_Tab);
        const closed = named(popout, "filter-done");
        tryCompare(closed, "activeFocus", true);
        keyClick(Qt.Key_Space);
        compare(widget.filter, "done");
        keyClick(Qt.Key_Tab);
        tryCompare(refresh, "activeFocus", true);
        named(popout, "filter-active").clicked();
        tryCompare(list, "count", 2);
        wait(50);
        const expand = named(list.itemAtIndex(0), "expandIssue-context");
        verify(expand.Accessible.name.length > 0);
        expand.forceActiveFocus();
        keyClick(Qt.Key_Space);
        tryCompare(list, "count", 1);
        named(list.itemAtIndex(0), "expandIssue-context").forceActiveFocus();
        keyClick(Qt.Key_Space);
        tryCompare(list, "count", 2);
        wait(50);
        const completeButton = named(list.itemAtIndex(1), "completeIssue-child");
        verify(completeButton.Accessible.name.length > 0);
        verify(named(list.itemAtIndex(1), "openIssue-child").Accessible.name.length > 0);
        completeButton.forceActiveFocus();
        tryCompare(completeButton, "activeFocus", true);
        keyClick(Qt.Key_Space);
        compare(request().variables.id, "child");
        complete(null, "network");
    }

    function test_ui_toolbar_initial_geometry_and_locale_changes() {
        bootstrap([issue("mine"), issue("done", "completed")]);
        makeUi();
        compare(popout.width, 400, "check the initial fixture width before resizing");
        function verifyToolbarFits() {
            const refresh = named(popout, "refreshIssues");
            const refreshPoint = refresh.mapToItem(popout, 0, 0);
            verify(refreshPoint.x >= 0 && refreshPoint.x + refresh.width <= popout.width,
                   "refresh stays within the initial popout");
            for (const key of ["active", "done"]) {
                const tab = named(popout, "filter-" + key);
                const tabPoint = tab.mapToItem(popout, 0, 0);
                verify(tabPoint.x >= 0 && tabPoint.x + tab.width <= refreshPoint.x,
                       "refresh does not overlap the " + key + " tab");
            }
        }
        verifyToolbarFits();
        I18n.localeTag = "zh_CN";
        I18n.pluginTranslations = ({dankTodo: {
            "Pending": {"Pending": "待完成"},
            "Closed": {"Closed": "已关闭"},
            "Refresh": {"Refresh": "刷新"}
        }});
        wait(0);
        verify(named(popout, "filter-active").text.includes("待完成"));
        verify(named(popout, "filter-done").text.includes("已关闭"));
        verifyToolbarFits();
        I18n.localeTag = "en_US";
        I18n.pluginTranslations = ({});
        wait(0);
        verify(named(popout, "filter-active").text.includes("Pending"));
        verifyToolbarFits();
    }

    function test_settings_paths_choices_and_popups() {
        bootstrap();
        makeUi();
        settings = settingsComponent.createObject(suite, {width: 500});
        verify(settings !== null);
        const countChoice = named(settings, "countMode");
        compare(descendants(settings, child => child.objectName === "defaultTeamId").length, 0);
        compare(countChoice.count, 4);
        countChoice.activated(3);
        compare(settings.values.countMode, "hidden");
        for (const choice of [countChoice]) {
            choice.popup.open();
            tryCompare(choice.popup, "visible", true);
            wait(50);
            verify(choice.popup.contentItem.count > 0, "popup delegates instantiate");
            choice.popup.close();
        }
        const path = named(settings, "apiKeyPath");
        path.text = " /fixture/custom-key ";
        path.editingFinished();
        compare(settings.values.apiKeyPath, "/fixture/custom-key");
        compare(TestIo.file.path, "/fixture/custom-key");
        verify(!JSON.stringify(SettingsData.pluginSettings).includes("fixture-key"));
        compare(TestIo.file.writeCount, 0);
    }

    function test_settings_reject_token_paste_before_save_or_reload() {
        bootstrap();
        settings = settingsComponent.createObject(suite, {width: 500});
        verify(settings !== null);
        const path = named(settings, "apiKeyPath");
        const reload = named(settings, "reloadCredentials");
        const storedValues = JSON.stringify(settings.values);
        const storedPreferences = JSON.stringify(SettingsData.pluginSettings);
        const reloads = TestIo.file.reloadCount;
        const requests = Api.history.length;
        for (const value of ["lin_api_fixture_accidental_paste", "~/linear-key", "relative/key"]) {
            path.text = " " + value + " ";
            path.editingFinished();
            wait(0);
            compare(JSON.stringify(settings.values), storedValues, "invalid value must not reach saveValue");
            compare(JSON.stringify(SettingsData.pluginSettings), storedPreferences);
            compare(TestIo.file.reloadCount, reloads);
            compare(Api.history.length, requests);
            compare(daemon.connected, true);
            compare(settings.keyPathError, "Enter an absolute file path, not an API key.");
            verify(!settings.keyPathError.includes(value), "error must not echo a pasted credential");
            reload.clicked();
            wait(0);
            compare(JSON.stringify(settings.values), storedValues, "reload button must also reject before saving");
            compare(JSON.stringify(SettingsData.pluginSettings), storedPreferences);
            compare(TestIo.file.reloadCount, reloads, "rejected paste must not reload credentials");
            compare(Api.history.length, requests);
            compare(daemon.viewer.id, "viewer");
        }
        path.text = " /fixture/key ";
        path.editingFinished();
        compare(settings.values.apiKeyPath, "/fixture/key");
        compare(SettingsData.pluginSettings.dankTodo.apiKeyPath, "/fixture/key");
        compare(TestIo.file.path, "/fixture/key");
        compare(settings.keyPathError, "");
        const savedReloads = TestIo.file.reloadCount;
        reload.clicked();
        wait(0);
        verify(TestIo.file.reloadCount > savedReloads, "valid absolute path permits explicit reload");
        path.text = "   ";
        path.editingFinished();
        compare(settings.values.apiKeyPath, "");
        compare(SettingsData.pluginSettings.dankTodo.apiKeyPath, "");
        compare(TestIo.file.path, "/fixture/config/dank-todo/linear-api-key");
        compare(settings.keyPathError, "");
        const defaultReloads = TestIo.file.reloadCount;
        reload.clicked();
        wait(0);
        verify(TestIo.file.reloadCount > defaultReloads, "empty path permits default credentials reload");
        verify(!JSON.stringify(SettingsData.pluginSettings).includes("lin_api_"));
        compare(TestIo.file.writeCount, 0);
    }

    function test_mock_popout_visual_snapshot_data() {
        let cases = [];
        for (const width of [460, 320])
            for (const mode of ["pending", "closed", "no-status", "working", "error"])
                cases.push({tag: width + "-" + mode, width: width, mode: mode});
        return cases;
    }

    function test_mock_popout_visual_snapshot(data) {
        const own = issue("own");
        own.title = "A long task title that must wrap without covering completion or open-in-Linear controls";
        own.team.name = "Team with a longer display name";
        own.dueDate = "2028-02-29";
        const done = issue("done", "completed");
        done.title = "Completed task with a long title remains readable in the closed view";
        const teams = [team()];
        if (data.mode === "no-status")
            teams[0].states = page([state("active", "started")]);
        bootstrap([issue("child", "started", issue("context", "completed")), own,
                   done, issue("canceled", "canceled")], teams);
        makeUi();
        popout.width = data.width;
        popout.height = 650;
        if (data.mode === "closed")
            named(popout, "filter-done").clicked();
        if (data.mode === "working" || data.mode === "error") {
            verify(daemon.completeIssue("own"));
            if (data.mode === "error")
                complete(null, "network");
        }
        wait(50);
        const list = named(popout, "issueList");
        verify(list.count > 0);
        for (let index = 0; index < list.count; index++) {
            const row = list.itemAtIndex(index);
            verify(row !== null);
            for (const name of ["completeIssue-", "openIssue-"]) {
                const action = named(row, name + row.modelData.id);
                const point = action.mapToItem(row, 0, 0);
                verify(point.x >= 0 && point.x + action.width <= row.width,
                       "row actions remain inside " + data.width + "px content");
            }
        }
        let finished = false;
        const path = decodeURIComponent(Qt.resolvedUrl("mock-popout-" + data.tag + ".png").toString().replace(/^file:\/\//, ""));
        const started = popout.grabToImage(function(result) {
            if (result.saveToFile(path))
                console.log("Mock-only popout screenshot: " + path);
            else
                console.log("Mock-only popout screenshot unavailable: image save failed");
            finished = true;
        }, Qt.size(data.width, 650));
        if (started)
            tryVerify(() => finished);
        else
            console.log("Mock-only popout screenshot unavailable: offscreen capture unsupported");
    }

    function test_live_locale_real_chinese_map_and_untranslated_user_title() {
        let table = null;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                table = JSON.parse(xhr.responseText);
        };
        // Actual transport reads only copied translations, never credentials or network.
        xhr.open("GET", Qt.resolvedUrl("plugin/translations/zh_CN.json"));
        xhr.send();
        tryVerify(() => table !== null);
        const mine = issue("mine");
        mine.title = "User title stays literal";
        bootstrap([mine]);
        makeUi();
        settings = settingsComponent.createObject(suite, {width: 500});
        verify(settings !== null);
        compare(popout.headerText, "My tasks");
        compare(popout.detailsText, "1 remaining");
        const hasText = (item, text) => descendants(item, child => child.text === text).length > 0;
        verify(hasText(settings, "Linear settings"));
        I18n.localeTag = "zh_CN";
        I18n.pluginTranslations = ({dankTodo: table});
        wait(0);
        compare(popout.headerText, "我的任务");
        compare(popout.detailsText, "1 项待完成");
        verify(hasText(settings, "Linear 设置"));
        verify(named(popout, "filter-active").text.includes("待完成"));
        verify(named(popout, "filter-done").text.includes("已关闭"));
        verify(hasText(popout, "User title stays literal"));
        daemon.teams = [{id: "team", states: [state("active", "started")]}];
        verify(descendants(popout, child => child.visible && child.text === "团队未配置完成状态").length > 0);
        verify(daemon.refresh());
        complete(null, "network");
        compare(daemon.error, "无法连接 Linear。请检查网络连接后刷新。");
        I18n.localeTag = "en_US";
        I18n.pluginTranslations = ({});
        wait(0);
        compare(popout.headerText, "My tasks");
        verify(named(popout, "filter-active").text.includes("Pending"));
        verify(named(popout, "filter-done").text.includes("Closed"));
        verify(hasText(popout, "User title stays literal"));
        compare(daemon.error, "Unable to reach Linear. Check your connection and refresh.",
                "existing backend errors must react to locale changes");
        compare(TestIo.file.writeCount, 0);
    }
}
