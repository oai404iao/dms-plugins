import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Common
import "plugin"

TestCase {
    id: suite
    name: "DankTodoIntegration"
    width: 600
    height: 900
    when: windowShown

    Component { id: widgetComponent; DankTodoWidget {} }
    Component { id: settingsComponent; DankTodoSettings {} }
    property var widget: null
    property var popout: null
    property var settings: null

    function init() {
        verify(Quickshell.isStub, "never load real Quickshell IO");
        I18n.localeTag = "en_US";
        I18n.pluginTranslations = ({});
        Quickshell.commands = [];
        widget = widgetComponent.createObject(suite);
        verify(widget !== null);
        verify(TestIo.file !== null);
        compare(TestIo.file.reloadCount, 1);
        compare(TestIo.file.writeCount, 0);
    }

    function cleanup() {
        if (settings) settings.destroy();
        if (popout) popout.destroy();
        if (widget) widget.destroy();
        settings = null;
        popout = null;
        widget = null;
        wait(0);
        TestIo.file = null;
        TestIo.ipc = null;
    }

    function task(id, parentId, extra) {
        return Object.assign({
            id: id, text: "Task " + id, parentId: parentId || null,
            completed: false, paused: false,
            createdAt: "2026-01-02T03:04:05.000Z",
            plannedAt: null, completedAt: null
        }, extra || {});
    }

    function load(tasks, version) {
        TestIo.file.inject(JSON.stringify({ version: version || 3, todos: tasks }));
    }

    function get(id) { return widget.todos.find(t => t.id === id); }
    function ids(tasks) { return tasks.map(t => t.id).join(","); }
    function saved() { return JSON.parse(TestIo.file.contents); }
    function iso(value) {
        verify(typeof value === "string" && !isNaN(new Date(value).getTime()),
               "expected a valid ISO timestamp: " + value);
        compare(new Date(value).toISOString(), value);
    }

    function descendants(item, predicate) {
        let found = [];
        if (predicate(item)) found.push(item);
        for (const child of item.children || [])
            found = found.concat(descendants(child, predicate));
        return found;
    }

    function test_add_subtask_edit_and_saved_dates() {
        const planned = widget.parsePlannedAt("2026-05-01 14:35");
        verify(widget.addTodo("  parent\n text  ", null, planned));
        const parent = widget.todos[0];
        compare(parent.text, "parent text");
        compare(parent.parentId, null);
        compare(parent.plannedAt, planned);
        compare(parent.completedAt, null);
        compare(parent.paused, false);
        iso(parent.createdAt);
        verify(widget.addTodo("Child", parent.id, null));
        const child = widget.todos[1];
        compare(child.parentId, parent.id);
        compare(child.plannedAt, null);
        verify(widget.editTodo(parent.id, " Renamed "));
        compare(get(parent.id).plannedAt, planned, "omitted plan must preserve it");
        verify(widget.editTodo(parent.id, "Renamed again", ""));
        compare(get(parent.id).plannedAt, null);
        compare(widget.addTodo("  ", null), false);
        compare(widget.editTodo(child.id, " "), false);
        compare(saved().version, 3);
        compare(saved().todos.length, 2);
        compare(saved().todos[0].createdAt, parent.createdAt);
    }

    function test_planning_valid_invalid_and_clear() {
        load([task("a")]);
        compare(widget.parsePlannedAt("2026-05-01"), "2026-05-01T00:00:00.000Z");
        compare(widget.parsePlannedAt(" 2026-05-01T14:35 "), "2026-05-01T14:35:00.000Z");
        compare(widget.parsePlannedAt("2024-02-29 23:59"), "2024-02-29T23:59:00.000Z");
        compare(widget.parsePlannedAt("  "), "");
        for (const invalid of ["tomorrow", "2026-02-29", "2026-04-31", "2026-00-01",
                               "2026-13-01", "2026-01-00", "2026-05-01 24:00",
                               "2026-05-01 12:60", "2026-5-1", "2026-05-01T12:00:00Z"])
            compare(widget.parsePlannedAt(invalid), null, invalid);
        verify(widget.planTodo("a", "2026-05-01 14:35"));
        const plan = get("a").plannedAt;
        const writes = TestIo.file.writeCount;
        compare(widget.planTodo("a", "invalid"), false);
        compare(get("a").plannedAt, plan);
        compare(TestIo.file.writeCount, writes, "invalid plan must not save");
        compare(widget.planTodo("missing", "2026-05-01"), false);
        verify(widget.planTodo("a", ""));
        compare(get("a").plannedAt, null);
        compare(saved().todos[0].plannedAt, null);
    }

    function test_date_display_and_composer_roundtrip() {
        compare(widget.displayTime(null), "Not set");
        compare(widget.displayTime("invalid"), "Not set");
        compare(widget.displayTime("2026-05-01T14:35:00.000Z"), "2026-05-01 14:35");
        compare(widget.plannedInput(null), "");
        compare(widget.plannedInput("invalid"), "");
        const isoDate = "2026-05-01T14:35:00.000Z";
        compare(widget.parsePlannedAt(widget.plannedInput(isoDate)), isoDate);
    }

    function test_pause_completion_reopen_counts_and_ipc() {
        load([task("a"), task("p", null, { paused: true }),
              task("d", null, { completed: true }), task("x", null, { deletedAt: "old" })]);
        compare(widget.visibleCount, 3);
        compare(widget.activeCount, 1);
        compare(widget.pausedCount, 1);
        compare(widget.doneCount, 1);
        compare(ids(widget.filteredTodos("active")), "a");
        compare(ids(widget.filteredTodos("paused")), "p");
        compare(ids(widget.filteredTodos("done")), "d");
        compare(ids(widget.filteredTodos("all")), "a,p,d");
        compare(TestIo.ipc.pause("a"), "OK");
        compare(widget.activeCount, 0);
        compare(widget.pausedCount, 2);
        TestIo.ipc.pause("a");
        compare(widget.activeCount, 1);
        widget.pauseTodo("d");
        compare(get("d").paused, false);
        widget.toggleTodo("p");
        compare(get("p").completed, true);
        compare(get("p").paused, false);
        iso(get("p").completedAt);
        compare(saved().todos.find(t => t.id === "p").completedAt, get("p").completedAt);
        widget.toggleTodo("p");
        compare(get("p").completed, false);
        compare(get("p").completedAt, null);
        compare(widget.activeCount, 2);
        for (const mode of ["active", "paused", "done", "total", "hidden"]) {
            widget.countMode = mode;
            compare(widget.pillCountLabel(), ({active:"2", paused:"0", done:"1", total:"3", hidden:""})[mode]);
        }
        compare(TestIo.ipc.plan("a", "bad"), "FAILED");
        compare(TestIo.ipc.plan("a", "2026-05-01"), "OK");
        compare(get("a").plannedAt, "2026-05-01T00:00:00.000Z");
        compare(TestIo.ipc.count(), "2/3");
    }

    function test_tree_context_collapse_and_noncontiguous_children() {
        load([task("root", null, {completed:true}), task("other"),
              task("leaf", "middle"), task("middle", "root", {paused:true}),
              task("doneChild", "root", {completed:true})]);
        const rows = widget.treeRows("active");
        compare(ids(rows), "root,middle,leaf,other");
        compare(rows.map(t => t.depth).join(","), "0,1,2,0");
        compare(rows.map(t => t.contextOnly).join(","), "true,true,false,false");
        compare(rows.map(t => t.hasChildren).join(","), "true,true,false,false");
        compare(ids(widget.filteredTodos("active")), "other,leaf", "context parents aren't exact matches");
        widget.toggleExpanded("middle");
        compare(ids(widget.treeRows("active")), "root,middle,other");
        widget.toggleExpanded("root");
        compare(ids(widget.treeRows("active")), "root,other");
        widget.toggleExpanded("root");
        widget.toggleExpanded("middle");
        compare(ids(widget.treeRows("active")), "root,middle,leaf,other");
        compare(ids(widget.treeRows("paused")), "root,middle");
        compare(ids(widget.treeRows("done")), "root,doneChild");
    }

    function test_move_and_delete_entire_noncontiguous_subtree() {
        load([task("source"), task("target"), task("grand", "child"),
              task("outside"), task("child", "source"), task("targetChild", "target")]);
        const before = JSON.stringify(widget.todos);
        widget.moveTodo("source", "grand", "child");
        compare(JSON.stringify(widget.todos), before, "cycle move must be rejected");
        widget.moveTodo("source", "target", "child");
        compare(get("source").parentId, "target");
        compare(get("child").parentId, "source");
        compare(get("grand").parentId, "child");
        compare(ids(widget.treeRows("all")), "target,source,child,grand,targetChild,outside");
        widget.moveTodo("source", "outside", "before");
        compare(get("source").parentId, null);
        compare(ids(widget.treeRows("all")), "target,targetChild,source,child,grand,outside");
        widget.moveTodo("source", "target", "after");
        compare(ids(widget.treeRows("all")), "target,targetChild,source,child,grand,outside");
        widget.deleteTodo("source");
        for (const id of ["source", "child", "grand"]) iso(get(id).deletedAt);
        compare(get("target").deletedAt, undefined);
        compare(get("outside").deletedAt, undefined);
        compare(ids(widget.treeRows("all")), "target,targetChild,outside");
        compare(saved().todos.filter(t => t.deletedAt).length, 3);
    }

    function test_clear_completed_promotes_unfinished_descendants() {
        load([task("root"), task("done", "root", {completed:true}),
              task("alsoDone", "done", {completed:true}), task("leaf", "alsoDone"),
              task("doneRoot", null, {completed:true}), task("paused", "doneRoot", {paused:true})]);
        widget.clearCompleted();
        compare(get("leaf").parentId, "root");
        compare(get("paused").parentId, null);
        compare(get("paused").paused, true);
        compare(ids(widget.treeRows("all")), "root,leaf,paused");
        compare(widget.visibleCount, 3);
        compare(widget.doneCount, 0);
        compare(saved().todos.find(t => t.id === "leaf").parentId, "root");
    }

    function test_load_legacy_v2_preserves_records_and_repairs_cycles() {
        const legacy = [
            {id:"old", text:"Old", completed:false, parentId:null, createdAt:"2025-01-01T00:00:00.000Z"},
            {id:"done", text:"Done", completed:true, parentId:"old", completedAt:"2025-02-01T12:00:00.000Z"},
            {id:"deleted", text:"Deleted", completed:false, deletedAt:"2025-03-01T00:00:00.000Z"},
            {id:"orphan", text:"Orphan", parentId:"missing"},
            {id:"child", text:"Child", parentId:"deleted"},
            {id:"cycle1", text:"Cycle 1", parentId:"cycle2"},
            {id:"cycle2", text:"Cycle 2", parentId:"cycle1"},
            {id:"self", text:"Self", parentId:"self"}
        ];
        load(legacy, 2);
        compare(widget.todos.length, legacy.length, "legacy completed/deleted records must survive");
        compare(get("old").createdAt, legacy[0].createdAt);
        compare(get("old").paused, false);
        compare(get("old").plannedAt, null);
        compare(get("old").completedAt, null);
        compare(get("done").completedAt, legacy[1].completedAt);
        compare(get("deleted").deletedAt, legacy[2].deletedAt);
        compare(get("orphan").parentId, null);
        compare(get("child").parentId, null);
        compare(get("self").parentId, null);
        verify(get("cycle1").parentId === null || get("cycle2").parentId === null);
        compare(widget.treeRows("all").length, legacy.length - 1);
        widget.saveTodos();
        compare(saved().version, 3);
        compare(saved().todos.length, legacy.length);
        const persisted = TestIo.file.contents;
        TestIo.file.inject(persisted);
        compare(widget.treeRows("all").length, legacy.length - 1);
    }

    function test_file_loading_bad_json_and_missing_file() {
        TestIo.file.inject("not JSON");
        compare(widget.todos.length, 0);
        TestIo.file.inject(JSON.stringify([task("array")]));
        compare(ids(widget.todos), "array");
        TestIo.file.loadFailed(2);
        compare(widget.todos.length, 0);
        compare(saved().version, 3);
        verify(Quickshell.commands.length >= 2, "mkdir requests intercepted by stub");
    }

    function test_real_popout_composer_list_and_settings_instantiate() {
        load([task("parent", null, {completed:true}), task("child", "parent"),
              task("paused", null, {paused:true})]);
        popout = widget.popoutContent.createObject(suite);
        verify(popout !== null);
        wait(0);
        const composers = descendants(popout, item => typeof item.submitComposer === "function");
        compare(composers.length, 1);
        const composer = composers[0];
        const fields = descendants(composer, item => item.placeholderText !== undefined
                                   && typeof item.selectAll === "function");
        compare(fields.length, 2, "real composer has todo text and planned date inputs");
        const textInput = fields[0], plannedInput = fields[1];
        composer.startAddingChild("parent");
        textInput.text = "New subtask";
        plannedInput.text = "invalid";
        compare(composer.submitComposer(), false);
        compare(composer.addingChildOfId, "parent", "invalid plan preserves composer state");
        plannedInput.text = "2026-05-01 14:35";
        verify(composer.submitComposer());
        const added = widget.todos.find(t => t.text === "New subtask");
        verify(added !== undefined);
        compare(added.parentId, "parent");
        compare(added.plannedAt, "2026-05-01T14:35:00.000Z");
        composer.startEditing(added.id);
        compare(plannedInput.text, "2026-05-01 14:35");
        plannedInput.text = "2026-02-29";
        compare(composer.submitComposer(), false);
        compare(composer.editingId, added.id);
        compare(get(added.id).plannedAt, "2026-05-01T14:35:00.000Z");
        textInput.text = "Edited subtask";
        plannedInput.text = "";
        verify(composer.submitComposer());
        compare(get(added.id).text, "Edited subtask");
        compare(get(added.id).plannedAt, null);
        composer.startEditing(added.id);
        composer.cancelComposer();
        compare(composer.editingId, "");
        compare(plannedInput.text, "");
        const lists = descendants(popout, item => typeof item.itemAtIndex === "function");
        compare(lists.length, 1);
        const list = lists[0];
        tryCompare(list, "count", widget.treeRows("active").length);
        verify(list.itemAtIndex(0) !== null, "real ListView delegates must instantiate");
        widget.toggleExpanded("parent");
        tryCompare(list, "count", 1, 5000, "context parent stays visible when collapsed");
        widget.toggleExpanded("parent");
        tryCompare(list, "count", widget.treeRows("active").length);
        for (const filter of ["all", "paused", "done", "active"]) {
            widget.filter = filter;
            tryCompare(list, "count", widget.treeRows(filter).length);
            wait(0);
        }
        const horizontal = widget.horizontalBarPill.createObject(suite);
        const vertical = widget.verticalBarPill.createObject(suite);
        verify(horizontal !== null && vertical !== null);
        horizontal.destroy();
        vertical.destroy();
        settings = settingsComponent.createObject(suite, {width:500});
        verify(settings !== null);
        wait(0);
        compare(settings.pluginId, "dankTodo");
        const paths = descendants(settings, item => item.placeholderText !== undefined
                                  && typeof item.selectAll === "function");
        compare(paths.length, 1);
        paths[0].text = " /fixture/custom ";
        paths[0].editingFinished();
        compare(settings.values.storagePath, "/fixture/custom");
    }

    function test_live_locale_switch_uses_real_chinese_translations() {
        let table = null;
        const request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE)
                table = JSON.parse(request.responseText);
        };
        // Reads only the translation fixture copied into this retained test directory.
        request.open("GET", Qt.resolvedUrl("plugin/translations/zh_CN.json"));
        request.send();
        tryVerify(() => table !== null);
        load([task("a", null, {text:"User text must not be translated"})]);
        popout = widget.popoutContent.createObject(suite);
        settings = settingsComponent.createObject(suite, {width:500});
        verify(popout !== null && settings !== null);
        const composer = descendants(popout, item => typeof item.submitComposer === "function")[0];
        const fields = descendants(composer, item => item.placeholderText !== undefined
                                  && typeof item.selectAll === "function");
        const textInput = fields[0];
        function hasText(item, text) {
            return descendants(item, child => child.text === text).length > 0;
        }
        compare(popout.headerText, "Todos");
        verify(hasText(settings, "Dank Todo Settings"));
        verify(hasText(popout, "Active (1)"));
        compare(textInput.placeholderText, "Add a todo and press Enter");
        I18n.localeTag = "zh_CN";
        I18n.pluginTranslations = ({dankTodo:table});
        wait(0);
        compare(popout.headerText, "待办");
        verify(hasText(settings, "Dank 待办设置"));
        verify(hasText(settings, "已暂停"));
        verify(hasText(popout, "进行中 (1)"));
        verify(hasText(popout, "已暂停 (0)"));
        compare(textInput.placeholderText, "输入待办，按回车添加");
        composer.startEditing("a");
        compare(textInput.placeholderText, "编辑后按回车保存");
        compare(textInput.text, "User text must not be translated");
        composer.cancelComposer();
        I18n.localeTag = "en_US";
        I18n.pluginTranslations = ({});
        wait(0);
        compare(popout.headerText, "Todos");
        verify(hasText(settings, "Dank Todo Settings"));
        verify(hasText(popout, "Active (1)"));
        compare(textInput.placeholderText, "Add a todo and press Enter");
        compare(get("a").text, "User text must not be translated");
        compare(TestIo.file.writeCount, 0, "locale switching must not rewrite user data");
    }
}
