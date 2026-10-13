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
    function team(id) {
        return {id: id || "team", name: "Test team", states: {
            nodes: [state("done", "completed", 2), state("active", "started", 1), state("cancel", "canceled", 3)],
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
    function bootstrap(tasks) {
        TestIo.file.inject("fixture-key\n");
        compare(request().query, Api.bootstrapQuery);
        complete({viewer: {id: "viewer", name: "Viewer"}, teams: page([team()])});
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
            complete({viewer: {id: "viewer", name: "Viewer"}, teams: page([team()])});
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

    function test_create_assigned_subtask_update_state_and_clear_date() {
        bootstrap();
        verify(daemon.createIssue("  Child title  ", "team", "mine", "2028-02-29"));
        compare(request().query, Api.createMutation);
        compare(JSON.stringify(request().variables.input), JSON.stringify({
            title: "Child title", teamId: "team", assigneeId: "viewer", parentId: "mine", dueDate: "2028-02-29"
        }));
        complete({issueCreate: {success: true, issue: {id: "new"}}});
        compare(mutationResults.join(","), "true");
        compare(request().query, Api.issuesQuery);
        complete({issues: page([issue("mine"), issue("new")])});
        verify(daemon.updateIssue("mine", " Renamed ", "cancel", ""));
        compare(request().query, Api.updateMutation);
        compare(JSON.stringify(request().variables), JSON.stringify({
            id: "mine", input: {title: "Renamed", stateId: "cancel", dueDate: null}
        }));
        complete({issueUpdate: {success: true}});
        complete({issues: page([issue("mine", "canceled")])});
        compare(daemon.doneCount, 1);
        compare(daemon.activeCount, 0);
        compare(TestIo.file.writeCount, 0);
    }

    function test_invalid_mutations_and_context_are_read_only() {
        bootstrap([issue("mine", "started", issue("context"))]);
        const calls = Api.history.length;
        for (const args of [
            ["", "team", "", ""], ["title", "missing", "", ""],
            ["title", "team", "context", ""], ["title", "team", "missing", ""],
            ["title", "team", "", "2026-02-29"]
        ]) compare(daemon.createIssue(...args), false);
        compare(daemon.updateIssue("context", "Changed", "active", ""), false);
        compare(daemon.updateIssue("mine", "Changed", "missing", ""), false);
        compare(daemon.updateIssue("mine", "Changed", "active", "2026-04-31"), false);
        compare(Api.history.length, calls);
    }

    function test_mutation_failure_signal_and_failed_refresh_retains_snapshot() {
        bootstrap();
        const snapshot = JSON.stringify(daemon.issues);
        const syncedAt = daemon.lastSyncedAt;
        verify(daemon.updateIssue("mine", "Changed", "done", ""));
        complete({issueUpdate: {success: false}});
        compare(mutationResults.join(","), "false");
        compare(JSON.stringify(daemon.issues), snapshot);
        verify(daemon.error.length > 0);
        verify(daemon.refresh());
        complete({viewer: {id: "viewer"}, teams: page([team()])});
        complete(null, "network");
        compare(daemon.busy, false);
        compare(JSON.stringify(daemon.issues), snapshot);
        compare(daemon.lastSyncedAt, syncedAt);
        verify(daemon.error.length > 0);
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
        verify(daemon.updateIssue("mine", "Uncertain", "done", ""));
        const outstanding = request();
        const timers = daemon.resources.filter(o => o.interval === 20000 && o.triggered !== undefined);
        compare(timers.length, 1);
        timers[0].triggered();
        verify(outstanding.canceled);
        compare(daemon.busy, false);
        compare(mutationResults.join(","), "false");
        verify(daemon.error.indexOf("timed out") >= 0);
        complete({issueUpdate: {success: true}});
        compare(mutationResults.join(","), "false");
        compare(daemon.issues[0].title, "Issue mine");
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
        for (const name of ["add", "edit", "delete", "plan", "pause", "setKey", "setToken"])
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
        compare(named(context, "editIssue-context").enabled, false);
        compare(named(context, "addChild-context").enabled, false);
        compare(named(context, "openIssue-context").enabled, true);
        const child = list.itemAtIndex(1);
        compare(named(child, "editIssue-child").enabled, true);
        compare(named(child, "addChild-child").enabled, true);
        widget.draftTitle = "Keep draft";
        widget.editIssue(widget.rows[0]);
        widget.addChild(widget.rows[0]);
        compare(widget.draftTitle, "Keep draft", "context actions cannot replace draft");
        widget.toggleExpanded("context");
        tryCompare(list, "count", 1);
        widget.toggleExpanded("context");
        tryCompare(list, "count", 2);
        for (const filter of ["done", "all", "active"]) {
            widget.filter = filter;
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

    function test_ui_drafts_clear_only_confirmed_success_and_survive_close() {
        bootstrap();
        makeUi();
        secondWidget.draftTitle = "Other widget draft";
        widget.editIssue(widget.rows[0]);
        compare(widget.editingId, "mine");
        widget.draftTitle = "Changed";
        widget.draftDate = "2026-02-29";
        widget.submitDraft();
        compare(widget.pendingSubmission, false);
        compare(widget.draftTitle, "Changed");
        compare(widget.editingId, "mine");
        verify(daemon.error.length > 0 || widget.composerError.length > 0);
        widget.draftDate = "2028-02-29";
        widget.submitDraft();
        compare(widget.pendingSubmission, true);
        compare(named(popout, "submitIssue").enabled, false);
        compare(named(popout, "issueTitle").enabled, false);
        verify(Api.pending.length > 0, "failed mutation queued");
        complete(null, "network");
        compare(widget.pendingSubmission, false);
        compare(widget.draftTitle, "Changed");
        compare(widget.draftDate, "2028-02-29");
        compare(widget.editingId, "mine");
        popout.destroy();
        popout = null;
        wait(0);
        compare(widget.draftTitle, "Changed");
        popout = widget.popoutContent.createObject(suite);
        verify(popout !== null);
        verify(Api.pending.length > 0, "reopened popout refresh queued");
        complete({viewer: {id: "viewer", name: "Viewer"}, teams: page([team()])});
        complete({issues: page([issue("mine")])});
        compare(named(popout, "issueTitle").text, "Changed");
        compare(named(popout, "dueDate").text, "2028-02-29");
        widget.submitDraft();
        compare(widget.pendingSubmission, true);
        verify(Api.pending.length > 0, "successful mutation queued");
        complete({issueUpdate: {success: true}});
        compare(widget.pendingSubmission, false);
        compare(widget.draftTitle, "");
        compare(widget.draftDate, "");
        compare(widget.editingId, "");
        compare(secondWidget.draftTitle, "Other widget draft", "another widget's draft must not clear");
        verify(Api.pending.length > 0, "post-mutation refresh queued");
        complete(null, "network");
        compare(widget.draftTitle, "", "confirmed write clears even when subsequent refresh fails");
        widget.addChild(widget.rows[0]);
        compare(widget.parentId, "mine");
        widget.draftTitle = "Subissue";
        widget.submitDraft();
        compare(request().variables.input.parentId, "mine");
        complete({issueCreate: {success: true}});
        complete({issues: page([issue("mine")])});
        compare(widget.parentId, "");
        compare(TestIo.file.writeCount, 0);
    }

    function test_ui_synchronous_transport_failure_retains_draft() {
        bootstrap();
        makeUi();
        widget.draftTitle = "Do not lose";
        Api.nextError = "network";
        widget.submitDraft();
        verify(widget.pendingSubmission, "failure callback must not race caller state");
        wait(0);
        compare(widget.pendingSubmission, false);
        compare(widget.draftTitle, "Do not lose");
        compare(mutationResults.join(","), "false");
        compare(daemon.busy, false);
    }

    function test_ui_draft_account_identity_boundary_and_same_viewer_rotation() {
        bootstrap();
        makeUi();
        widget.draftTitle = "Original account draft";
        widget.draftDate = "2028-02-29";
        widget.teamId = "team";
        secondWidget.draftDate = "2028-03-01";
        compare(widget.draftAccountId, "viewer", "first title captures draft identity");
        compare(secondWidget.draftAccountId, "viewer", "first date also captures draft identity");
        daemon.reloadCredentials();
        TestIo.file.inject("rotated-fixture-key");
        complete({viewer: {id: "viewer", name: "Same viewer"}, teams: page([team()])});
        complete({issues: page([issue("mine")])});
        compare(widget.draftAccountChanged, false);
        compare(widget.canWrite, true);
        compare(named(popout, "submitIssue").enabled, true);
        widget.submitDraft();
        compare(widget.pendingSubmission, true, "same viewer key rotation keeps submit usable");
        compare(request().variables.input.assigneeId, "viewer");
        complete(null, "network");
        compare(widget.draftTitle, "Original account draft");
        compare(widget.draftDate, "2028-02-29");
        daemon.reloadCredentials();
        TestIo.file.inject("other-account-fixture-key");
        complete({viewer: {id: "other-viewer", name: "Other viewer"}, teams: page([team()])});
        complete({issues: page([issue("other")])});
        compare(widget.draftAccountId, "viewer");
        compare(widget.draftAccountChanged, true);
        compare(widget.canWrite, false);
        compare(named(popout, "submitIssue").enabled, false);
        compare(named(popout, "issueTitle").enabled, false);
        compare(named(popout, "dueDate").enabled, false);
        const calls = Api.history.length;
        widget.submitDraft();
        widget.editIssue(widget.rows[0]);
        widget.addChild(widget.rows[0]);
        compare(Api.history.length, calls, "account mismatch cannot start any write");
        compare(widget.pendingSubmission, false);
        compare(widget.draftTitle, "Original account draft");
        compare(widget.draftDate, "2028-02-29");
        compare(widget.teamId, "team");
        compare(widget.editingId, "");
        compare(widget.parentId, "");
        const warning = "Account changed. Cancel this draft before continuing.";
        verify(descendants(popout, child => child.text === warning).length > 0);
        let table = null;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                table = JSON.parse(xhr.responseText);
        };
        xhr.open("GET", Qt.resolvedUrl("plugin/translations/zh_CN.json"));
        xhr.send();
        tryVerify(() => table !== null);
        I18n.localeTag = "zh_CN";
        I18n.pluginTranslations = ({dankTodo: table});
        wait(0);
        verify(descendants(popout, child => child.text === "账户已变更。请先取消此草稿再继续。").length > 0);
        const cancel = named(popout, "cancelDraft");
        compare(cancel.enabled, true);
        cancel.clicked();
        compare(widget.draftAccountId, "");
        compare(widget.draftAccountChanged, false);
        compare(widget.canWrite, true);
        compare(widget.draftTitle, "");
        compare(widget.draftDate, "");
        verify(descendants(popout, child => child.text === "账户已变更。请先取消此草稿再继续。").length === 0);
        widget.draftTitle = "New account draft";
        compare(widget.draftAccountId, "other-viewer");
        compare(named(popout, "submitIssue").enabled, true, "cancel restores submit usability for a new draft");
    }

    function test_settings_paths_choices_and_popups() {
        bootstrap();
        makeUi();
        settings = settingsComponent.createObject(suite, {width: 500});
        verify(settings !== null);
        const teamChoice = named(settings, "defaultTeamId");
        const countChoice = named(settings, "countMode");
        compare(teamChoice.count, 1);
        compare(countChoice.count, 4);
        countChoice.activated(3);
        compare(settings.values.countMode, "hidden");
        teamChoice.activated(0);
        compare(settings.values.defaultTeamId, "team");
        for (const choice of [teamChoice, countChoice, named(popout, "issueChoice")]) {
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

    function test_mock_popout_visual_snapshot() {
        bootstrap([issue("child", "started", issue("context", "completed")), issue("own")]);
        makeUi();
        popout.width = 500;
        popout.height = 650;
        wait(50);
        let finished = false;
        const path = decodeURIComponent(Qt.resolvedUrl("mock-popout.png").toString().replace(/^file:\/\//, ""));
        const started = popout.grabToImage(function(result) {
            if (result.saveToFile(path))
                console.log("Mock-only popout screenshot: " + path);
            else
                console.log("Mock-only popout screenshot unavailable: image save failed");
            finished = true;
        }, Qt.size(500, 650));
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
        compare(popout.headerText, "My Linear issues");
        compare(named(popout, "issueTitle").placeholderText, "Issue title");
        const hasText = (item, text) => descendants(item, child => child.text === text).length > 0;
        verify(hasText(settings, "Linear settings"));
        I18n.localeTag = "zh_CN";
        I18n.pluginTranslations = ({dankTodo: table});
        wait(0);
        compare(popout.headerText, "我的 Linear 事项");
        compare(named(popout, "issueTitle").placeholderText, "事项标题");
        verify(hasText(settings, "Linear 设置"));
        verify(hasText(popout, "未完成"));
        verify(hasText(popout, "User title stays literal"));
        widget.editIssue(widget.rows[0]);
        compare(named(popout, "issueTitle").text, "User title stays literal");
        compare(named(popout, "submitIssue").text, "保存更改");
        widget.draftDate = "2026-02-29";
        widget.submitDraft();
        compare(daemon.error, "截止日期请使用 YYYY-MM-DD 格式，或留空。");
        I18n.localeTag = "en_US";
        I18n.pluginTranslations = ({});
        wait(0);
        compare(popout.headerText, "My Linear issues");
        compare(named(popout, "submitIssue").text, "Save changes");
        compare(widget.draftTitle, "User title stays literal");
        compare(daemon.error, "Use YYYY-MM-DD for the due date, or leave it empty.",
                "existing backend errors must react to locale changes");
        compare(TestIo.file.writeCount, 0);
    }
}
