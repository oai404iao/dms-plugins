.pragma library

var endpoint = "https://api.linear.app/graphql";
var fields = "id identifier title url createdAt completedAt dueDate "
    + "state { id name color type } team { id name }";
var issueFields = fields + " parent { " + fields + " parent { id } }";
var bootstrapQuery = "query Bootstrap($after: String) { viewer { id name } "
    + "teams(first: 10, after: $after) { nodes { id name "
    + "states(first: 100) { nodes { id name color type position } pageInfo { hasNextPage } } } "
    + "pageInfo { hasNextPage endCursor } } }";
var issuesQuery = "query MyIssues($viewer: ID!, $after: String) { "
    + "issues(first: 100, after: $after, filter: { assignee: { id: { eq: $viewer } } }, orderBy: updatedAt) "
    + "{ nodes { " + issueFields + " } pageInfo { hasNextPage endCursor } } }";
var parentQuery = "query Parent($id: String!) { issue(id: $id) { " + issueFields + " } }";
var createMutation = "mutation CreateIssue($input: IssueCreateInput!) { "
    + "issueCreate(input: $input) { success issue { id } } }";
var updateMutation = "mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) { "
    + "issueUpdate(id: $id, input: $input) { success issue { id } } }";

// One request at a time is owned and timed out by the daemon, never by a bar instance.
function request(key, query, variables, callback) {
    var xhr = new XMLHttpRequest();
    var settled = false;
    function finish(data, error) {
        if (settled)
            return;
        settled = true;
        callback(data, error);
    }
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE || settled)
            return;
        if (xhr.status === 401 || xhr.status === 403) {
            finish(null, "auth");
            return;
        }
        if (xhr.status === 429) {
            finish(null, "rate");
            return;
        }
        var body;
        try {
            body = JSON.parse(xhr.responseText);
        } catch (_) {
            finish(null, xhr.status >= 200 && xhr.status < 300 ? "response" : "network");
            return;
        }
        if (!body || typeof body !== "object" || Array.isArray(body)
                || (body.errors !== undefined && !Array.isArray(body.errors))) {
            finish(null, "response");
            return;
        }
        if (body.errors && body.errors.length) {
            var limited = body.errors.some(e => e && e.extensions
                && (e.extensions.code === "RATELIMITED" || e.extensions.code === "RATE_LIMITED"));
            finish(null, limited ? "rate" : "response");
            return;
        }
        if (xhr.status < 200 || xhr.status >= 300) {
            finish(null, "network");
            return;
        }
        if (!body.data || typeof body.data !== "object" || Array.isArray(body.data)) {
            finish(null, "response");
            return;
        }
        finish(body.data, "");
    };
    xhr.onerror = function () { finish(null, "network"); };
    try {
        xhr.open("POST", endpoint);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", key);
        xhr.send(JSON.stringify({ query: query, variables: variables }));
    } catch (_) {
        finish(null, "network");
    }
    return { cancel: function () { settled = true; xhr.abort(); } };
}

function validDate(value) {
    if (!value)
        return true;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value))
        return false;
    var date = new Date(value + "T00:00:00Z");
    return !isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function validPage(page) {
    return page && Array.isArray(page.nodes) && page.pageInfo
        && typeof page.pageInfo.hasNextPage === "boolean"
        && (!page.pageInfo.hasNextPage || !!page.pageInfo.endCursor);
}

function validIssue(issue) {
    return issue && issue.id && typeof issue.title === "string"
        && issue.state && issue.state.id && issue.team && issue.team.id;
}

function isDone(issue) {
    return ["completed", "canceled", "duplicate"].includes(issue.state.type);
}

function treeRows(issues, filterKey, collapsedIds) {
    var byId = new Map(issues.map(t => [t.id, t]));
    var matches = new Set(issues.filter(t => t.isMine
        && (filterKey === "all" || (filterKey === "done" ? isDone(t) : !isDone(t)))).map(t => t.id));
    var included = new Set(matches);
    for (var id of matches) {
        var task = byId.get(id);
        while (task && task.parent && !included.has(task.parent.id)) {
            included.add(task.parent.id);
            task = byId.get(task.parent.id);
        }
    }
    var children = new Map();
    for (var issue of issues) {
        var parentId = issue.parent && byId.has(issue.parent.id) ? issue.parent.id : null;
        if (!children.has(parentId))
            children.set(parentId, []);
        children.get(parentId).push(issue);
    }
    var rows = [];
    function visit(issue, depth) {
        if (!included.has(issue.id))
            return;
        var branch = (children.get(issue.id) || []).filter(t => included.has(t.id));
        rows.push(Object.assign({}, issue, {
            depth: depth, hasChildren: branch.length > 0, contextOnly: !matches.has(issue.id)
        }));
        if (!collapsedIds.includes(issue.id))
            branch.forEach(t => visit(t, depth + 1));
    }
    (children.get(null) || []).forEach(t => visit(t, 0));
    return rows;
}
