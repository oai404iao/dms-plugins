import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../plugins/dankTodo/LinearApi.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/u, "");
const requests = [];
let throwAt = "";
class Xhr {
    static DONE = 4;
    constructor() { this.headers = {}; requests.push(this); }
    open(method, url) {
        if (throwAt === "open") throw new Error("mock setup failure");
        this.method = method; this.url = url;
    }
    setRequestHeader(name, value) {
        if (throwAt === "header") throw new Error("mock header failure");
        this.headers[name] = value;
    }
    send(body) {
        if (throwAt === "send") throw new Error("mock send failure");
        this.body = JSON.parse(body);
    }
    abort() { this.aborted = true; }
    respond(status, body) {
        this.status = status;
        this.responseText = typeof body === "string" ? body : JSON.stringify(body);
        this.readyState = Xhr.DONE;
        this.onreadystatechange();
    }
}
const api = vm.createContext({ XMLHttpRequest: Xhr });
vm.runInContext(source, api, { filename: "LinearApi.js" });
const plain = value => JSON.parse(JSON.stringify(value));
let checks = 0;
function test(name, run) {
    run();
    checks++;
    console.log(`PASS ${name}`);
}
function send(query = api.updateMutation, variables = {}) {
    const calls = [];
    const handle = api.request("fixture-not-a-real-key", query, variables,
        (data, error) => calls.push({ data, error }));
    return { xhr: requests.at(-1), calls, handle };
}
test("GraphQL uses fixed endpoint, raw API key header and JSON variables", () => {
    const id = '" } mutation Malicious { deleteEverything } #\nUnicode 中文';
    const { xhr, calls } = send(api.updateMutation, { id, input: { stateId: "completed-state" } });
    assert.equal(xhr.method, "POST");
    assert.equal(xhr.url, "https://api.linear.app/graphql");
    assert.deepEqual(xhr.headers, { "Content-Type": "application/json", Authorization: "fixture-not-a-real-key" });
    assert.equal(xhr.body.query, api.updateMutation);
    assert.match(xhr.body.query, /\$input: IssueUpdateInput!/);
    assert.match(xhr.body.query, /issueUpdate\(id: \$id, input: \$input\)/);
    assert.equal(xhr.body.query.includes(id), false);
    assert.deepEqual(xhr.body.variables, { id, input: { stateId: "completed-state" } });
    xhr.respond(200, { data: { issueUpdate: { success: true, issue: { id } } } });
    assert.deepEqual(plain(calls), [{ data: { issueUpdate: { success: true, issue: { id } } }, error: "" }]);
    xhr.onerror();
    assert.equal(calls.length, 1, "request settles exactly once");
});
test("queries declare cursors, own assignee filter and native issue fields", () => {
    assert.match(api.bootstrapQuery, /teams\(first: 10, after: \$after\)/);
    assert.match(api.issuesQuery, /assignee: \{ id: \{ eq: \$viewer \} \}/);
    assert.match(api.issuesQuery, /after: \$after/);
    assert.match(api.issuesQuery, /orderBy: updatedAt/);
    for (const field of ["identifier", "createdAt", "completedAt", "dueDate", "parent", "state", "team"])
        assert.ok(api.issuesQuery.includes(field), field);
    assert.match(api.parentQuery, /issue\(id: \$id\)/);
});
test("HTTP and GraphQL errors including HTTP 200 failures", () => {
    for (const [status, body, code] of [
        [401, {}, "auth"], [403, {}, "auth"], [429, {}, "rate"],
        [0, {}, "network"], [500, {}, "network"], [200, "not JSON", "response"],
        [200, "null", "response"], [200, "[]", "response"], [200, "42", "response"],
        [200, {data: "bad"}, "response"], [200, {data: []}, "response"],
        [200, {errors: "bad", data: {}}, "response"], [200, {errors: [null]}, "response"],
        [200, {}, "response"], [200, { errors: [{ message: "rejected" }], data: {} }, "response"],
        [200, { errors: [{ extensions: { code: "RATELIMITED" } }] }, "rate"],
        [400, { errors: [{ extensions: { code: "RATELIMITED" } }] }, "rate"],
        [200, { errors: [{ extensions: { code: "RATE_LIMITED" } }] }, "rate"]
    ]) {
        const { xhr, calls } = send();
        xhr.respond(status, body);
        assert.deepEqual(plain(calls), [{ data: null, error: code }], `${status} ${JSON.stringify(body)}`);
    }
    const { xhr, calls } = send();
    xhr.onerror();
    assert.deepEqual(plain(calls), [{ data: null, error: "network" }]);
});
test("synchronous setup/header/send failures settle as network errors", () => {
    for (const stage of ["open", "header", "send"]) {
        throwAt = stage;
        const { calls } = send();
        assert.deepEqual(plain(calls), [{data: null, error: "network"}], stage);
    }
    throwAt = "";
});
test("cancellation aborts transport and suppresses late callbacks", () => {
    const { xhr, calls, handle } = send();
    handle.cancel();
    assert.equal(xhr.aborted, true);
    xhr.respond(200, { data: {} });
    xhr.onerror();
    assert.equal(calls.length, 0);
});
test("native done/canceled/duplicate and ancestor context, filtering and collapse", () => {
    const issue = (id, type, parentId, isMine = true) =>
        ({ id, state: { type }, parent: parentId ? { id: parentId } : null, isMine });
    const issues = [issue("root", "completed", null, false), issue("other", "started"),
        issue("leaf", "started", "middle"), issue("middle", "canceled", "root", false),
        issue("done", "completed"), issue("canceled", "canceled"), issue("duplicate", "duplicate")];
    const rows = plain(api.treeRows(issues, "active", []));
    assert.deepEqual(rows.map(r => r.id), ["root", "middle", "leaf", "other"]);
    assert.deepEqual(rows.map(r => r.depth), [0, 1, 2, 0]);
    assert.deepEqual(rows.map(r => r.contextOnly), [true, true, false, false]);
    assert.deepEqual(rows.map(r => r.hasChildren), [true, true, false, false]);
    assert.deepEqual(plain(api.treeRows(issues, "active", ["middle"])).map(r => r.id), ["root", "middle", "other"]);
    assert.deepEqual(plain(api.treeRows(issues, "done", [])).map(r => r.id), ["done", "canceled", "duplicate"]);
    assert.equal(api.isDone(issue("x", "unstarted")), false);
    assert.equal(api.isDone(issue("x", "canceled")), true);
    assert.equal(api.isDone(issue("x", "duplicate")), true);
});
console.log(`DMS Linear API checks passed (${checks} groups; mocked transport only)`);
